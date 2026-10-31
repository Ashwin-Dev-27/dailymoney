import 'package:flutter/material.dart';

import '../models/tx.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';

/// Central transaction store + derived aggregations for the UI.
class TransactionsProvider extends ChangeNotifier {
  TransactionsProvider(this._storage);

  final StorageService _storage;

  final List<Tx> _txs = [];

  /// All transactions, newest date first.
  List<Tx> get all => List.unmodifiable(_txs);

  bool get isEmpty => _txs.isEmpty;
  int get count => _txs.length;

  // ── Persistence ───────────────────────────────────────────

  Future<void> load() async {
    _txs
      ..clear()
      ..addAll(await _storage.loadTransactions());
    _sortByDate();
    notifyListeners();
  }

  Future<void> add(Tx tx) async {
    _txs.add(tx);
    _sortByDate();
    notifyListeners();
    await _storage.saveTransactions(_txs);
  }

  /// Inserts many transactions with a single disk write.
  Future<void> addAll(List<Tx> txs) async {
    _txs.addAll(txs);
    _sortByDate();
    notifyListeners();
    await _storage.saveTransactions(_txs);
  }

  Future<void> update(Tx tx) async {
    final i = _txs.indexWhere((t) => t.id == tx.id);
    if (i < 0) return add(tx);
    _txs[i] = tx;
    _sortByDate();
    notifyListeners();
    await _storage.saveTransactions(_txs);
  }

  Future<void> remove(String id) async {
    _txs.removeWhere((t) => t.id == id);
    notifyListeners();
    await _storage.saveTransactions(_txs);
  }

  Future<int> removeAll() async {
    final n = _txs.length;
    _txs.clear();
    notifyListeners();
    await _storage.saveTransactions(_txs);
    return n;
  }

  void _sortByDate() => _txs.sort((a, b) => b.date.compareTo(a.date));

  // ── Derived figures ───────────────────────────────────────

  ({double income, double expense}) totalsFor(DateTime month) {
    var income = 0.0, expense = 0.0;
    for (final t in _txs) {
      if (t.date.year != month.year || t.date.month != month.month) continue;
      if (t.type.isIncome) {
        if (!t.isSettlement) income += t.amount;
      } else {
        expense += t.personalExpense;
      }
    }
    return (income: income, expense: expense);
  }

  /// Income and expense recorded on a single calendar day.
  ({double income, double expense}) totalsOn(DateTime day) {
    var income = 0.0, expense = 0.0;
    for (final t in _txs) {
      if (t.date.year != day.year ||
          t.date.month != day.month ||
          t.date.day != day.day) {
        continue;
      }
      if (t.type.isIncome) {
        if (!t.isSettlement) income += t.amount;
      } else {
        expense += t.personalExpense;
      }
    }
    return (income: income, expense: expense);
  }

  /// Expenses recorded on a single calendar day.
  double expenseOn(DateTime day) => totalsOn(day).expense;

  double get balance {
    var sum = 0.0;
    for (final t in _txs) {
      sum += t.balanceDelta;
    }
    return sum;
  }

  /// Expense sums per category id for [month], descending.
  Map<String, double> expenseByCategory(DateTime month) {
    final map = <String, double>{};
    for (final t in _txs) {
      if (t.date.year != month.year || t.date.month != month.month) continue;
      if (t.type != TxType.expense) continue;
      final amount = t.personalExpense;
      if (amount <= 0) continue;
      map[t.categoryId] = (map[t.categoryId] ?? 0) + amount;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  /// Income/expense pairs for the last [months] months ending at [ending].
  List<({DateTime month, double income, double expense})> monthlySeries({
    int months = 6,
    DateTime? ending,
  }) {
    final end = monthOf(ending ?? DateTime.now());
    final out = <({DateTime month, double income, double expense})>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(end.year, end.month - i);
      final t = totalsFor(m);
      out.add((month: m, income: t.income, expense: t.expense));
    }
    return out;
  }

  /// Transactions filtered for the Transactions screen.
  List<Tx> filtered({
    String query = '',
    TxType? type,
    DateTime? month,
  }) {
    final q = query.trim().toLowerCase();
    return _txs.where((t) {
      if (type != null && t.type != type) return false;
      if (month != null &&
          !(t.date.year == month.year && t.date.month == month.month)) {
        return false;
      }
      if (q.isEmpty) return true;
      final title = t.title.toLowerCase();
      final note = t.note.toLowerCase();
      return title.contains(q) || note.contains(q);
    }).toList();
  }

  /// The five most recent transactions.
  List<Tx> recent([int n = 5]) => all.take(n).toList(growable: false);
}
