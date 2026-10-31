import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/services/storage_service.dart';

/// Builds a provider bound to a mock SharedPreferences store.
/// Returns the storage so reload tests can share it.
Future<(StorageService, TransactionsProvider)> makeProvider() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return (storage, TransactionsProvider(storage));
}

Tx tx(
  String id, {
  double amount = 10,
  bool income = false,
  String category = 'other',
  DateTime? date,
  String title = 'T',
}) {
  return Tx(
    id: id,
    title: title,
    amount: amount,
    type: income ? TxType.income : TxType.expense,
    categoryId: category,
    date: date ?? DateTime(2026, 10, 15),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionsProvider', () {
    test('add/update/remove keeps storage in sync', () async {
      final (storage, p) = await makeProvider();
      await p.add(tx('1', amount: 100, income: true));
      await p.add(tx('2', amount: 40));
      expect(p.count, 2);

      await p.update(tx('2', amount: 55));
      expect(p.all.firstWhere((t) => t.id == '2').amount, 55);

      await p.remove('1');
      expect(p.count, 1);

      // Reload from disk: changes persisted.
      final p2 = TransactionsProvider(storage);
      await p2.load();
      expect(p2.count, 1);
      expect(p2.all.first.id, '2');
      expect(p2.all.first.amount, 55);
    });

    test('balance is income minus expense', () async {
      final (_, p) = await makeProvider();
      await p.addAll([
        tx('a', amount: 300, income: true),
        tx('b', amount: 80),
        tx('c', amount: 20),
      ]);
      expect(p.balance, 200);
    });

    test('totalsFor filters by month', () async {
      final (_, p) = await makeProvider();
      await p.addAll([
        tx('a', amount: 100, income: true, date: DateTime(2026, 9, 2)),
        tx('b', amount: 50, date: DateTime(2026, 10, 1)),
        tx('c', amount: 25, date: DateTime(2026, 10, 20)),
        tx('d', amount: 200, income: true, date: DateTime(2026, 10, 3)),
      ]);
      final oct = p.totalsFor(DateTime(2026, 10));
      expect(oct.income, 200);
      expect(oct.expense, 75);
      final sep = p.totalsFor(DateTime(2026, 9));
      expect(sep.income, 100);
      expect(sep.expense, 0);
    });

    test('expenseByCategory sums per category, sorted desc', () async {
      final (_, p) = await makeProvider();
      await p.addAll([
        tx('a', amount: 30, category: 'food'),
        tx('b', amount: 70, category: 'rent'),
        tx('c', amount: 10, category: 'food'),
        tx('d', amount: 15, category: 'food', income: true),
      ]);
      final byCat = p.expenseByCategory(DateTime(2026, 10));
      expect(byCat.keys.toList(), ['rent', 'food']);
      expect(byCat['rent'], 70);
      expect(byCat['food'], 40);
    });

    test('filtered matches query, type and month', () async {
      final (_, p) = await makeProvider();
      await p.addAll([
        tx('1',
            title: 'Coffee shop',
            amount: 5,
            category: 'food',
            date: DateTime(2026, 10, 2)),
        tx('2',
            title: 'Salary',
            amount: 900,
            income: true,
            category: 'salary',
            date: DateTime(2026, 10, 1)),
        tx('3',
            title: 'September rent',
            amount: 800,
            category: 'rent',
            date: DateTime(2026, 9, 1)),
      ]);

      expect(p.filtered().length, 3);
      expect(p.filtered(query: 'coffee').length, 1);
      expect(p.filtered(type: TxType.income).length, 1);
      expect(p.filtered(month: DateTime(2026, 9)).length, 1);
      expect(p.filtered(query: 'rent', month: DateTime(2026, 10)).length, 0);
    });

    test('monthlySeries spans N months ending now', () async {
      final (_, p) = await makeProvider();
      final now = DateTime(2026, 10, 15);
      final series = p.monthlySeries(months: 6, ending: now);
      expect(series.length, 6);
      expect(series.first.month, DateTime(2026, 5));
      expect(series.last.month, DateTime(2026, 10));
    });
  });

  group('SettingsProvider', () {
    test('persists currency, budget, theme and seeded flag', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final s1 = SettingsProvider(storage);
      await s1.load();
      await s1.setCurrency('INR');
      await s1.setMonthlyBudget(15000);
      await s1.setThemeMode(ThemeMode.dark);
      await s1.markSeeded();

      final s2 = SettingsProvider(storage);
      await s2.load();
      expect(s2.currencyCode, 'INR');
      expect(s2.monthlyBudget, 15000);
      expect(s2.themeMode, ThemeMode.dark);
      expect(s2.seeded, isTrue);
    });

    test('negative budget clamps to zero', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final s = SettingsProvider(storage);
      await s.load();
      await s.setMonthlyBudget(-5);
      expect(s.monthlyBudget, 0);
    });

    test('persists name, rollover, briefing and alert preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final s1 = SettingsProvider(storage);
      await s1.load();
      await s1.setUserName('  Ashwin  ');
      await s1.setCarryForward(false);
      await s1.setMorningBriefing(false);
      await s1.setNightSummary(false);
      await s1.setBudgetAlerts(false);
      await s1.setMorningTime(const TimeOfDay(hour: 7, minute: 15));
      await s1.setNightTime(const TimeOfDay(hour: 22, minute: 45));
      await s1.markNotificationsAsked();

      final s2 = SettingsProvider(storage);
      await s2.load();
      expect(s2.userName, 'Ashwin');
      expect(s2.carryForward, isFalse);
      expect(s2.morningBriefing, isFalse);
      expect(s2.nightSummary, isFalse);
      expect(s2.budgetAlerts, isFalse);
      expect(s2.morningMinutes, 7 * 60 + 15);
      expect(s2.nightMinutes, 22 * 60 + 45);
      expect(s2.notificationsAsked, isTrue);
      expect(s2.morningTime, const TimeOfDay(hour: 7, minute: 15));
    });

    test('notification settings default to off at 08:00 and 21:00', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final s = SettingsProvider(storage);
      await s.load();
      expect(s.carryForward, isTrue);
      expect(s.morningBriefing, isFalse);
      expect(s.nightSummary, isFalse);
      expect(s.budgetAlerts, isFalse);
      expect(s.notificationsConsent, isFalse);
      expect(s.morningTime, const TimeOfDay(hour: 8, minute: 0));
      expect(s.nightTime, const TimeOfDay(hour: 21, minute: 0));
    });
  });
}
