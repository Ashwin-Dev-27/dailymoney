import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/shared_expense.dart';
import '../models/tx.dart';
import '../services/storage_service.dart';
import 'transactions_provider.dart';

/// Tracks money shared with friends, roommates and family.
///
/// A split expense records the full payment in the ledger but only the user's
/// share in spending statistics. Repayments are settlements: they change the
/// balance but are never counted as new income.
class SharedProvider extends ChangeNotifier {
  SharedProvider(this._storage);

  final StorageService _storage;
  final List<SharedExpense> _items = [];

  List<SharedExpense> get all {
    final list = List<SharedExpense>.from(_items)
      ..sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        return b.date.compareTo(a.date);
      });
    return List.unmodifiable(list);
  }

  List<SharedExpense> get open =>
      all.where((e) => !e.isSettled).toList(growable: false);

  List<SharedExpense> byDirection(SharedDirection direction) =>
      all.where((e) => e.direction == direction).toList(growable: false);

  double get owedToMe => _items
      .where((e) => e.direction == SharedDirection.owedToMe)
      .fold(0.0, (sum, e) => sum + e.outstanding);

  double get iOwe => _items
      .where((e) => e.direction == SharedDirection.iOwe)
      .fold(0.0, (sum, e) => sum + e.outstanding);

  double get net => owedToMe - iOwe;

  bool get isEmpty => _items.isEmpty;

  int get count => _items.length;

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await _storage.loadSharedExpenses());
    notifyListeners();
  }

  Future<void> add(SharedExpense item) async {
    _items.add(item);
    notifyListeners();
    await _storage.saveSharedExpenses(_items);
  }

  Future<void> update(SharedExpense item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i < 0) return add(item);
    _items[i] = item;
    notifyListeners();
    await _storage.saveSharedExpenses(_items);
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _storage.saveSharedExpenses(_items);
  }

  Future<int> removeAll() async {
    final n = _items.length;
    _items.clear();
    notifyListeners();
    await _storage.saveSharedExpenses(_items);
    return n;
  }

  SharedExpense? byLinkedTx(String txId) {
    for (final item in _items) {
      if (item.linkedTxId == txId) return item;
    }
    return null;
  }

  SharedExpense? _byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Keeps the shared record in step with a transaction created from the Add
  /// sheet. Only expenses with a smaller personal share produce a record.
  Future<void> syncForTransaction(Tx tx, {Tx? previous}) async {
    // A settlement entry owns part of a shared record's `settled` total.
    // Keep that total correct when the entry is edited, or when its type is
    // switched from a receipt to an expense.
    final oldSettlementId = previous?.settlementOf;
    final newSettlementId = tx.settlementOf;
    if (oldSettlementId != null || newSettlementId != null) {
      final id = oldSettlementId ?? newSettlementId!;
      final item = _byId(id);
      if (item != null) {
        var settled = item.settled;
        if (previous != null && previous.settlementOf == id) {
          settled -= previous.amount;
        }
        if (newSettlementId == id) {
          settled += tx.amount;
        }
        await update(item.copyWith(
          settled: settled.clamp(0.0, item.owed).toDouble(),
        ));
      }
    }

    if (!tx.isSharedExpense) {
      final existing = byLinkedTx(tx.id);
      if (existing != null) {
        if (existing.settled <= 0.005) {
          await remove(existing.id);
        } else {
          // Keep the settlement history; there is nothing left to collect.
          await update(existing.copyWith(myShare: existing.total));
        }
      }
      return;
    }

    final existing = byLinkedTx(tx.id);
    if (existing == null) {
      await add(SharedExpense(
        id: const Uuid().v4(),
        title: tx.title,
        total: tx.amount,
        myShare: tx.personalExpense,
        direction: SharedDirection.owedToMe,
        date: tx.date,
        categoryId: tx.categoryId,
        linkedTxId: tx.id,
        note: tx.note,
      ));
    } else {
      await update(existing.copyWith(
        title: tx.title,
        total: tx.amount,
        myShare: tx.personalExpense,
        date: tx.date,
        categoryId: tx.categoryId,
        note: tx.note,
      ));
    }
  }

  /// Cleans up the shared record affected by deleting [tx].
  ///
  /// Deleting a settlement reverses its part of `settled`. Deleting the
  /// expense that created a split also removes every repayment recorded
  /// against it and the shared record itself; keeping those inflows without
  /// the expense they offset would inflate the balance.
  Future<void> removeForTransaction(
    Tx tx,
    TransactionsProvider txs,
  ) async {
    final settlementId = tx.settlementOf;
    if (settlementId != null) {
      final item = _byId(settlementId);
      if (item != null) {
        final settled = (item.settled - tx.amount).clamp(0.0, item.owed);
        await update(item.copyWith(settled: settled.toDouble()));
      }
      return;
    }

    final existing = byLinkedTx(tx.id);
    if (existing == null) return;
    for (final settlement in txs.all.toList()) {
      if (settlement.settlementOf == existing.id) {
        await txs.remove(settlement.id);
      }
    }
    await remove(existing.id);
  }

  /// Records a repayment and updates the outstanding amount.
  ///
  /// Receiving money back is a settlement, not income. Paying someone back is
  /// real spending for the user (it was never counted before), so it is
  /// recorded as a normal expense.
  Future<Tx?> settle(
    SharedExpense item,
    double amount,
    TransactionsProvider txs, {
    DateTime? now,
  }) async {
    final value = math.min(math.max(0.0, amount), item.outstanding);
    if (value <= 0.005) return null;
    final at = now ?? DateTime.now();
    final isReceipt = item.direction == SharedDirection.owedToMe;
    final tx = Tx(
      id: const Uuid().v4(),
      title: '${isReceipt ? 'Received' : 'Paid'} · ${item.title}',
      amount: value,
      type: isReceipt ? TxType.income : TxType.expense,
      categoryId: isReceipt ? 'other-income' : item.categoryId,
      date: DateTime(at.year, at.month, at.day, at.hour, at.minute),
      note: isReceipt ? 'Repayment — not income' : 'Shared expense payment',
      isSettlement: isReceipt,
      settlementOf: item.id,
    );
    await txs.add(tx);
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      _items[i] = item.copyWith(settled: item.settled + value);
      notifyListeners();
      await _storage.saveSharedExpenses(_items);
    }
    return tx;
  }
}
