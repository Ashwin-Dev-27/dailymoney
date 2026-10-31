import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/savings_goal.dart';
import '../models/tx.dart';
import '../models/upcoming_expense.dart';

/// Deterministic demo transactions for a fresh install: the last 4 months
/// of believable income/expense activity so charts and lists have data.
class DemoSeed {
  final _uuid = const Uuid();

  /// Two believable savings goals for a fresh install.
  List<SavingsGoal> generateGoals() {
    final now = DateTime.now();
    return [
      SavingsGoal(
        id: _uuid.v4(),
        title: 'Emergency fund',
        target: 50000,
        saved: 12500,
        targetDate: DateTime(now.year, now.month + 8, 15),
        note: 'Three months of essentials',
      ),
      SavingsGoal(
        id: _uuid.v4(),
        title: 'New laptop',
        target: 80000,
        saved: 20000,
        targetDate: DateTime(now.year, now.month + 5, 1),
      ),
    ];
  }

  /// Generates roughly 85 transactions ending today.
  List<Tx> generate() {
    final rnd = Random(2026);
    final now = DateTime.now();
    final txs = <Tx>[];

    void add(int year, int month, int day, TxType type, String categoryId,
        String title, double amount,
        [String note = '']) {
      final daysInMonth =
          DateTime(year, month + 1, 0).day; // overflow trick → day count
      final capped = day
          .clamp(
            1,
            month == now.month && year == now.year
                ? max(1, now.day)
                : daysInMonth,
          )
          .toInt();
      txs.add(Tx(
        id: _uuid.v4(),
        title: title,
        amount: (amount * 100).roundToDouble() / 100,
        type: type,
        categoryId: categoryId,
        date: DateTime(year, month, capped),
        note: note,
      ));
    }

    for (var i = 3; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      // Fixed monthly income + rent.
      add(m.year, m.month, 1, TxType.income, 'salary', 'Monthly salary', 4200);
      add(m.year, m.month, 3, TxType.expense, 'rent', 'Apartment rent', 1250);

      if (rnd.nextBool()) {
        add(m.year, m.month, 8 + rnd.nextInt(14), TxType.income, 'freelance',
            'Freelance project', 180 + rnd.nextInt(420).toDouble());
      }
      if (i.isOdd) {
        add(m.year, m.month, 20 - rnd.nextInt(10), TxType.income, 'investments',
            'Dividend payout', 60 + rnd.nextInt(140).toDouble());
      }

      for (var g = 0; g < 4 + rnd.nextInt(3); g++) {
        add(m.year, m.month, 1 + rnd.nextInt(27), TxType.expense, 'groceries',
            'Supermarket run', 22 + rnd.nextInt(98).toDouble());
      }
      for (var f = 0; f < 3 + rnd.nextInt(3); f++) {
        add(m.year, m.month, 1 + rnd.nextInt(27), TxType.expense, 'food',
            _foodName(rnd), 9 + rnd.nextInt(36).toDouble());
      }
      for (var t = 0; t < 3 + rnd.nextInt(2); t++) {
        add(m.year, m.month, 1 + rnd.nextInt(27), TxType.expense, 'transport',
            _transportName(rnd), 3 + rnd.nextInt(22).toDouble());
      }
      add(m.year, m.month, 12 + rnd.nextInt(6), TxType.expense, 'utilities',
          'Electricity & water', 55 + rnd.nextInt(65).toDouble());
      for (var e = 0; e < 2 + rnd.nextInt(2); e++) {
        add(m.year, m.month, 1 + rnd.nextInt(27), TxType.expense,
            'entertainment', _funName(rnd), 12 + rnd.nextInt(48).toDouble());
      }
      for (var s = 0; s < 1 + rnd.nextInt(2); s++) {
        add(m.year, m.month, 1 + rnd.nextInt(27), TxType.expense, 'shopping',
            'Shopping trip', 25 + rnd.nextInt(120).toDouble());
      }
      if (rnd.nextBool()) {
        add(m.year, m.month, 5 + rnd.nextInt(20), TxType.expense, 'health',
            'Pharmacy visit', 15 + rnd.nextInt(75).toDouble());
      }
      if (rnd.nextInt(3) == 0) {
        add(m.year, m.month, 10 + rnd.nextInt(12), TxType.expense, 'travel',
            'Weekend getaway', 90 + rnd.nextInt(260).toDouble());
      }
    }

    txs.sort((a, b) => b.date.compareTo(a.date));
    return txs;
  }

  /// A few believable unpaid bills for a fresh install.
  List<UpcomingExpense> generateUpcoming() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime inDays(int days) => today.add(Duration(days: days));

    return [
      UpcomingExpense(
        id: _uuid.v4(),
        title: 'Electricity bill',
        amount: 86,
        categoryId: 'utilities',
        dueDate: inDays(3),
        repeatMonthly: true,
      ),
      UpcomingExpense(
        id: _uuid.v4(),
        title: 'Apartment rent',
        amount: 1250,
        categoryId: 'rent',
        dueDate: inDays(5),
        repeatMonthly: true,
      ),
      UpcomingExpense(
        id: _uuid.v4(),
        title: 'Music subscription',
        amount: 12,
        categoryId: 'entertainment',
        dueDate: inDays(10),
        repeatMonthly: true,
      ),
    ];
  }

  String _foodName(Random r) => const [
        'Coffee & pastry',
        'Lunch at cafe',
        'Pizza night',
        'Dinner out',
        'Noodle bar',
        'Bakery stop',
      ][r.nextInt(6)];

  String _transportName(Random r) => const [
        'Bus pass top-up',
        'Ride share',
        'Fuel',
        'Taxi to station',
        'Metro ticket',
      ][r.nextInt(5)];

  String _funName(Random r) => const [
        'Cinema tickets',
        'Stream subscription',
        'Board game night',
        'Concert',
        'Bowling with friends',
      ][r.nextInt(5)];
}
