import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/tx.dart';
import '../models/upcoming_expense.dart';
import '../services/storage_service.dart';
import 'transactions_provider.dart';

/// Expected bills and recurring expenses that have not been paid yet.
class UpcomingProvider extends ChangeNotifier {
  UpcomingProvider(this._storage);

  final StorageService _storage;
  final List<UpcomingExpense> _items = [];

  /// All items, soonest due first.
  List<UpcomingExpense> get all {
    final list = List<UpcomingExpense>.from(_items)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return List.unmodifiable(list);
  }

  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await _storage.loadUpcoming());
    notifyListeners();
  }

  Future<void> add(UpcomingExpense item) async {
    _items.add(item);
    notifyListeners();
    await _storage.saveUpcoming(_items);
  }

  /// Inserts many items with a single disk write.
  Future<void> addAll(List<UpcomingExpense> items) async {
    _items.addAll(items);
    notifyListeners();
    await _storage.saveUpcoming(_items);
  }

  Future<void> update(UpcomingExpense item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i < 0) return add(item);
    _items[i] = item;
    notifyListeners();
    await _storage.saveUpcoming(_items);
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _storage.saveUpcoming(_items);
  }

  Future<int> removeAll() async {
    final n = _items.length;
    _items.clear();
    notifyListeners();
    await _storage.saveUpcoming(_items);
    return n;
  }

  /// Whether an item still needs money set aside for [month].
  ///
  /// Any unpaid item due on or before the end of the month counts: monthly
  /// items stay reserved while overdue, and a one-time bill that was not paid
  /// in its own month is still an obligation in later months.
  bool isDueIn(UpcomingExpense item, DateTime month) {
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return !item.dueDate.isAfter(end);
  }

  List<UpcomingExpense> dueInMonth(DateTime month) =>
      all.where((e) => isDueIn(e, month)).toList(growable: false);

  /// Money that must be kept back this month for unpaid upcoming bills.
  double reservedForMonth(DateTime month) {
    var sum = 0.0;
    for (final item in _items) {
      if (isDueIn(item, month)) sum += item.amount;
    }
    return sum;
  }

  /// The next [limit] unpaid items, for the Home preview.
  List<UpcomingExpense> nextUpcoming({int limit = 3}) =>
      all.take(limit).toList(growable: false);

  /// Records the bill as an expense and moves a repeating bill to its next
  /// occurrence (one-time bills are removed).
  Future<Tx> markPaid(UpcomingExpense item, TransactionsProvider txs) async {
    final now = DateTime.now();
    final tx = Tx(
      id: const Uuid().v4(),
      title: item.title,
      amount: item.amount,
      type: TxType.expense,
      categoryId: item.categoryId,
      date: DateTime(now.year, now.month, now.day, now.hour, now.minute),
      note: item.note.isEmpty ? 'Upcoming bill' : item.note,
    );
    await txs.add(tx);

    if (item.repeatMonthly) {
      final today = DateTime(now.year, now.month, now.day);
      var next = addMonthsClamped(item.dueDate, 1);
      while (next.isBefore(today)) {
        next = addMonthsClamped(next, 1);
      }
      await update(item.copyWith(dueDate: next));
    } else {
      await remove(item.id);
    }
    return tx;
  }
}
