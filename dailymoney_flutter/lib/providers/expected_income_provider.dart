import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/expected_income.dart';
import '../models/tx.dart';
import '../services/storage_service.dart';
import 'transactions_provider.dart';

/// Expected money is deliberately kept out of the ledger until it arrives.
class ExpectedIncomeProvider extends ChangeNotifier {
  ExpectedIncomeProvider(this._storage);

  final StorageService _storage;
  final List<ExpectedIncome> _items = [];

  List<ExpectedIncome> get all {
    final list = List<ExpectedIncome>.from(_items)
      ..sort((a, b) {
        if (a.received != b.received) return a.received ? 1 : -1;
        return a.expectedDate.compareTo(b.expectedDate);
      });
    return List.unmodifiable(list);
  }

  List<ExpectedIncome> get pending =>
      all.where((e) => !e.received).toList(growable: false);

  List<ExpectedIncome> get received =>
      all.where((e) => e.received).toList(growable: false);

  ExpectedIncome? get nextPending => pending.isEmpty ? null : pending.first;

  double get pendingTotal =>
      pending.fold(0.0, (sum, item) => sum + item.amount);

  bool get isEmpty => _items.isEmpty;

  int get count => _items.length;

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await _storage.loadExpectedIncome());
    notifyListeners();
  }

  Future<void> add(ExpectedIncome item) async {
    _items.add(item);
    notifyListeners();
    await _storage.saveExpectedIncome(_items);
  }

  Future<void> update(ExpectedIncome item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i < 0) return add(item);
    _items[i] = item;
    notifyListeners();
    await _storage.saveExpectedIncome(_items);
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _storage.saveExpectedIncome(_items);
  }

  Future<int> removeAll() async {
    final n = _items.length;
    _items.clear();
    notifyListeners();
    await _storage.saveExpectedIncome(_items);
    return n;
  }

  /// Marks the expected money as received and records the actual income.
  ///
  /// This is the only path that turns expected money into confirmed money, so
  /// the ledger never contains money that has not arrived.
  Future<Tx?> markReceived(
    ExpectedIncome item,
    TransactionsProvider txs, {
    DateTime? now,
  }) async {
    // Read the stored copy: the caller may hold a stale instance after a
    // previous tap, and marking the same expected money twice would create
    // duplicate income.
    final index = _items.indexWhere((e) => e.id == item.id);
    if (item.received || (index >= 0 && _items[index].received)) return null;
    final at = now ?? DateTime.now();
    final tx = Tx(
      id: const Uuid().v4(),
      title: item.title.trim().isEmpty ? 'Expected income' : item.title.trim(),
      amount: item.amount,
      type: TxType.income,
      categoryId: item.categoryId,
      date: DateTime(at.year, at.month, at.day, at.hour, at.minute),
      note: item.note.isEmpty ? 'Expected income received' : item.note,
    );
    await txs.add(tx);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(received: true, receivedDate: at);
      notifyListeners();
      await _storage.saveExpectedIncome(_items);
    }
    return tx;
  }
}
