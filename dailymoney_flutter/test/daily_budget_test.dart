import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/models/upcoming_expense.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/services/daily_budget.dart';
import 'package:dailymoney/services/storage_service.dart';

Tx expense(String id, double amount, DateTime date) => Tx(
      id: id,
      title: 'Expense $id',
      amount: amount,
      type: TxType.expense,
      categoryId: 'other',
      date: date,
    );

Tx income(String id, double amount, DateTime date) => Tx(
      id: id,
      title: 'Income $id',
      amount: amount,
      type: TxType.income,
      categoryId: 'salary',
      date: date,
    );

UpcomingExpense bill(
  String id,
  double amount,
  DateTime due, {
  bool monthly = false,
}) =>
    UpcomingExpense(
      id: id,
      title: 'Bill $id',
      amount: amount,
      categoryId: 'bills',
      dueDate: due,
      repeatMonthly: monthly,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settings;
  late UpcomingProvider upcoming;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    settings = SettingsProvider(storage);
    await settings.load();
    upcoming = UpcomingProvider(storage);
    await upcoming.load();
    await settings.setMonthlyBudget(3100);
  });

  group('DailyBudget.snapshot', () {
    test('carry-forward spreads what is left across remaining days', () {
      final today = DateTime(2026, 10, 15);
      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: [
          expense('past', 200, DateTime(2026, 10, 10)),
          expense('today', 40, today),
          income('salary', 4200, DateTime(2026, 10, 1)),
        ],
        upcoming: upcoming,
        today: today,
      );

      expect(snapshot.hasBudget, isTrue);
      expect(snapshot.daysInMonth, 31);
      expect(snapshot.daysLeft, 17);
      expect(snapshot.spentToday, 40);
      expect(snapshot.spentYesterday, 0);
      expect(snapshot.monthExpense, 240);
      expect(snapshot.allowance, closeTo((3100 - 200) / 17, 0.0001));
      expect(snapshot.remainingToday, closeTo((3100 - 200) / 17 - 40, 0.0001));
      // 14 full days at the base daily rate minus everything already spent.
      expect(snapshot.rolledOver, closeTo(1200, 0.0001));
      expect(snapshot.monthlyLeft, 2860);
    });

    test('future-dated expenses also reduce the remaining allowance', () {
      final today = DateTime(2026, 10, 15);
      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: [
          expense('past', 200, DateTime(2026, 10, 10)),
          expense('today', 40, today),
          expense('future', 500, DateTime(2026, 10, 25)),
        ],
        upcoming: upcoming,
        today: today,
      );

      expect(snapshot.spentToday, 40);
      expect(snapshot.monthExpense, 740);
      // 200 past + 40 today + 500 future are all committed this month.
      expect(snapshot.allowance, closeTo((3100 - 700) / 17, 0.0001));
      expect(snapshot.monthlyLeft, 3100 - 740);
    });

    test('carry-forward off uses a flat allowance every day', () async {
      await settings.setCarryForward(false);
      final today = DateTime(2026, 10, 15);
      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: [
          expense('past', 200, DateTime(2026, 10, 10)),
          expense('today', 40, today),
        ],
        upcoming: upcoming,
        today: today,
      );

      expect(snapshot.allowance, closeTo(100, 0.0001));
      expect(snapshot.remainingToday, closeTo(60, 0.0001));
      expect(snapshot.rolledOver, 0);
    });

    test('remaining can go negative when today is over the allowance', () {
      final today = DateTime(2026, 10, 15);
      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: [expense('big', 500, today)],
        upcoming: upcoming,
        today: today,
      );

      expect(snapshot.remainingToday, lessThan(0));
      expect(snapshot.spentRatio, greaterThan(1));
    });

    test('upcoming bills are reserved before the allowance is split', () async {
      await upcoming.addAll([
        bill('rent', 500, DateTime(2026, 10, 20)),
        // An overdue recurring bill still needs money this month.
        bill('power', 100, DateTime(2026, 9, 5), monthly: true),
        // A one-time bill next month must not be reserved in October.
        bill('next', 300, DateTime(2026, 11, 1)),
      ]);

      final today = DateTime(2026, 10, 15);
      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: [
          expense('past', 200, DateTime(2026, 10, 10)),
          expense('today', 40, today),
        ],
        upcoming: upcoming,
        today: today,
      );

      expect(upcoming.reservedForMonth(DateTime(2026, 10)), 600);
      expect(snapshot.reservedUpcoming, 600);
      expect(snapshot.allowance, closeTo((3100 - 200 - 600) / 17, 0.0001));
      expect(snapshot.monthlyLeft, closeTo(3100 - 240 - 600, 0.0001));
    });

    test('overdue one-time bills stay reserved until paid', () async {
      await upcoming.add(
        bill('late', 75, DateTime(2026, 9, 20)),
      );

      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: const [],
        upcoming: upcoming,
        today: DateTime(2026, 10, 15),
      );

      expect(upcoming.reservedForMonth(DateTime(2026, 10)), 75);
      expect(snapshot.reservedUpcoming, 75);
      expect(snapshot.allowance, closeTo((3100 - 75) / 17, 0.0001));
    });

    test('rolled-over money accounts for reserved bills', () async {
      await upcoming.add(
        bill('rent', 310, DateTime(2026, 10, 20)),
      );

      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: const [],
        upcoming: upcoming,
        today: DateTime(2026, 10, 15),
      );

      // 14 days at (3100 - 310) / 31 per day, with nothing spent yet.
      expect(
        snapshot.rolledOver,
        closeTo((3100 - 310) / 31 * 14, 0.0001),
      );
    });

    test('no budget reports hasBudget false but still tracks spending',
        () async {
      await settings.setMonthlyBudget(0);
      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: [expense('a', 30, DateTime(2026, 10, 15))],
        upcoming: upcoming,
        today: DateTime(2026, 10, 15),
      );

      expect(snapshot.hasBudget, isFalse);
      expect(snapshot.allowance, 0);
      expect(snapshot.remainingToday, 0);
      expect(snapshot.monthExpense, 30);
    });

    test('previous-month expenses are ignored', () {
      final snapshot = DailyBudget.snapshot(
        settings: settings,
        transactions: [
          expense('september', 900, DateTime(2026, 9, 30)),
          expense('october', 10, DateTime(2026, 10, 2)),
        ],
        upcoming: upcoming,
        today: DateTime(2026, 10, 15),
      );

      expect(snapshot.monthExpense, 10);
    });
  });

  group('DailyBudget.reportRows', () {
    test('current month stops at today, past months include every day', () {
      final now = DateTime(2026, 10, 15);
      final current = DailyBudget.reportRows(
        settings: settings,
        transactions: const [],
        upcoming: upcoming,
        month: DateTime(2026, 10),
        today: now,
      );
      expect(current.length, 15);
      expect(current.first.date, DateTime(2026, 10, 1));
      expect(current.last.date, DateTime(2026, 10, 15));

      final past = DailyBudget.reportRows(
        settings: settings,
        transactions: const [],
        upcoming: upcoming,
        month: DateTime(2026, 9),
        today: now,
      );
      expect(past.length, 30);
      expect(past.last.date, DateTime(2026, 9, 30));
    });

    test('each row compares that day against its allowance', () {
      final rows = DailyBudget.reportRows(
        settings: settings,
        transactions: [
          expense('a', 100, DateTime(2026, 9, 1)),
          income('b', 50, DateTime(2026, 9, 1)),
          expense('c', 30, DateTime(2026, 9, 2)),
        ],
        upcoming: upcoming,
        month: DateTime(2026, 9),
        today: DateTime(2026, 10, 15),
      );

      // Day 1: 3100 / 30 available; 100 spent.
      expect(rows[0].allowance, closeTo(3100 / 30, 0.0001));
      expect(rows[0].income, 50);
      expect(rows[0].expense, 100);
      expect(rows[0].remaining, closeTo(3100 / 30 - 100, 0.0001));
      expect(rows[0].isOver, isFalse);
      expect(rows[0].hadSpending, isTrue);
      expect(rows[0].hadExpense, isTrue);

      // Day 2: the 100 spent yesterday is deducted before splitting.
      expect(rows[1].allowance, closeTo((3100 - 100) / 29, 0.0001));
      expect(rows[1].remaining, closeTo((3100 - 100) / 29 - 30, 0.0001));
    });

    test('income-only days do not count as spent days', () {
      final rows = DailyBudget.reportRows(
        settings: settings,
        transactions: [income('pay', 500, DateTime(2026, 9, 3))],
        upcoming: upcoming,
        month: DateTime(2026, 9),
        today: DateTime(2026, 10, 15),
      );

      expect(rows[2].income, 500);
      expect(rows[2].expense, 0);
      expect(rows[2].hadExpense, isFalse);
      expect(rows[2].hadSpending, isTrue);
    });

    test('no budget leaves allowance and remaining at zero', () async {
      await settings.setMonthlyBudget(0);
      final rows = DailyBudget.reportRows(
        settings: settings,
        transactions: [expense('a', 10, DateTime(2026, 9, 3))],
        upcoming: upcoming,
        month: DateTime(2026, 9),
        today: DateTime(2026, 10, 15),
      );
      expect(rows.every((r) => r.allowance == 0), isTrue);
      expect(rows.every((r) => r.remaining == 0), isTrue);
      expect(rows[2].expense, 10);
    });

    test('past-month rows ignore bills still tracked for today', () async {
      await upcoming.add(
        bill('overdue', 500, DateTime(2026, 8, 1), monthly: true),
      );
      final rows = DailyBudget.reportRows(
        settings: settings,
        transactions: [expense('a', 100, DateTime(2026, 9, 1))],
        upcoming: upcoming,
        month: DateTime(2026, 9),
        today: DateTime(2026, 10, 15),
      );
      // The August bill is reserved for the current month, not September.
      expect(rows[0].allowance, closeTo(3100 / 30, 0.0001));
    });
  });

  group('addMonthsClamped', () {
    test('keeps the day when possible and clamps to short months', () {
      expect(addMonthsClamped(DateTime(2026, 1, 15), 1), DateTime(2026, 2, 15));
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(
          addMonthsClamped(DateTime(2024, 2, 29), 12), DateTime(2025, 2, 28));
      expect(
          addMonthsClamped(DateTime(2026, 12, 10), 1), DateTime(2027, 1, 10));
    });
  });
}
