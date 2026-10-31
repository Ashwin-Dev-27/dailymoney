import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/screens/reports_screen.dart';
import 'package:dailymoney/services/storage_service.dart';
import 'package:dailymoney/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('monthly budget changes are recorded per month and survive reload',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();

    final now = DateTime.now();
    await settings.setMonthlyBudget(3100);
    expect(settings.budgetForMonth(now), 3100);
    expect(settings.budgetHistory[SettingsProvider.monthKey(now)], 3100);

    await settings.setMonthlyBudget(4200);
    final reloaded = SettingsProvider(storage);
    await reloaded.load();
    expect(reloaded.monthlyBudget, 4200);
    expect(reloaded.budgetForMonth(now), 4200);

    final previous = DateTime(now.year, now.month - 1);
    expect(reloaded.budgetForMonth(previous), isNull);
  });

  test('historical values win over the current budget', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();

    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);
    await storage.saveSettings({
      'monthlyBudget': 3000,
      'budgetHistory': {
        SettingsProvider.monthKey(previous): 1200,
        SettingsProvider.monthKey(now): 3000,
      },
    });

    final settings = SettingsProvider(storage);
    await settings.load();
    expect(settings.budgetForMonth(previous), 1200);
    expect(settings.budgetForMonth(now), 3000);
  });

  test('export includes the budget history', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    await settings.setMonthlyBudget(2500);

    final backup = jsonDecode(await storage.exportJson()) as Map;
    final exported = backup['settings'] as Map;
    final history = exported['budgetHistory'] as Map;
    expect(history[SettingsProvider.monthKey(DateTime.now())], 2500);
  });

  testWidgets('reports use the recorded budget for a past month',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();

    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);
    await storage.saveSettings({
      'monthlyBudget': 3000,
      'budgetHistory': {
        SettingsProvider.monthKey(previous): 1200,
        SettingsProvider.monthKey(now): 3000,
      },
    });

    final settings = SettingsProvider(storage);
    await settings.load();
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: transactions),
          ChangeNotifierProvider.value(value: upcoming),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ReportsScreen(initialMonth: previous),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('\$1,200.00'), findsWidgets);
    expect(find.textContaining('No budget was recorded'), findsNothing);
  });

  testWidgets('a month with no record is labelled as a current-budget fallback',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();

    final now = DateTime.now();
    await storage.saveSettings({
      'monthlyBudget': 3000,
      'budgetHistory': {
        SettingsProvider.monthKey(now): 3000,
      },
    });

    final settings = SettingsProvider(storage);
    await settings.load();
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: transactions),
          ChangeNotifierProvider.value(value: upcoming),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ReportsScreen(initialMonth: DateTime(now.year, now.month - 2)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No budget was recorded for this month'),
        findsOneWidget);
    expect(find.textContaining('Showing your current budget'), findsOneWidget);
  });
}
