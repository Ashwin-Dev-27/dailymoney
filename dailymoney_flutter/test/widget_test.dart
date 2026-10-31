import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/app.dart';
import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/models/upcoming_expense.dart';
import 'package:dailymoney/providers/capture_provider.dart';
import 'package:dailymoney/providers/expected_income_provider.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/providers/security_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/shared_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/screens/settings_screen.dart';
import 'package:dailymoney/services/storage_service.dart';

/// Builds the full provider graph the app expects.
Future<Widget> harness({
  required StorageService storage,
  required SettingsProvider settings,
  required TransactionsProvider transactions,
  required UpcomingProvider upcoming,
  bool firstRun = false,
}) async {
  if (!firstRun && !settings.welcomeSeen) {
    // Most tests describe an existing install. The welcome gate is covered by
    // its own tests, so skip it here instead of duplicating it everywhere.
    await settings.dismissWelcome();
  }
  final goals = GoalsProvider(storage);
  await goals.load();
  final capture = CaptureProvider(storage);
  await capture.load();
  final security = SecurityProvider(storage);
  await security.load();
  final expected = ExpectedIncomeProvider(storage);
  await expected.load();
  final shared = SharedProvider(storage);
  await shared.load();

  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: transactions),
      ChangeNotifierProvider.value(value: upcoming),
      ChangeNotifierProvider.value(value: goals),
      ChangeNotifierProvider.value(value: capture),
      ChangeNotifierProvider.value(value: security),
      ChangeNotifierProvider.value(value: expected),
      ChangeNotifierProvider.value(value: shared),
    ],
    child: const DailyMoneyApp(),
  );
}

/// App boots and renders the home screen without throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DailyMoneyApp renders home with empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();

    await tester.pumpWidget(await harness(
      storage: storage,
      settings: settings,
      transactions: transactions,
      upcoming: upcoming,
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('DailyMoney'),
      ),
      findsOneWidget,
    );
    // First-run nudge to set a budget.
    expect(find.text('Set your monthly budget'), findsOneWidget);
    // The empty recent-activity state sits below the fold on small screens.
    await tester.scrollUntilVisible(find.text('No transactions yet'), 300);
    expect(find.text('No transactions yet'), findsOneWidget);

    // Navigation bar tabs are present.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Home shows daily allowance and reserved bills', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    await settings.setMonthlyBudget(3100);
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final now = DateTime.now();
    await transactions.add(Tx(
      id: 'lunch',
      title: 'Lunch',
      amount: 40,
      type: TxType.expense,
      categoryId: 'food',
      date: DateTime(now.year, now.month, now.day),
    ));
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();
    await upcoming.add(UpcomingExpense(
      id: 'power',
      title: 'Electricity',
      amount: 100,
      categoryId: 'utilities',
      dueDate: DateTime(now.year, now.month, now.day),
      repeatMonthly: true,
    ));

    await tester.pumpWidget(await harness(
      storage: storage,
      settings: settings,
      transactions: transactions,
      upcoming: upcoming,
    ));
    await tester.pumpAndSettle();

    expect(find.text("Today's spending money"), findsOneWidget);
    expect(find.text('left today'), findsOneWidget);
    expect(find.textContaining('allowance'), findsWidgets);
    expect(find.textContaining('Bills set aside'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Upcoming bills'), 300);
    expect(find.text('Upcoming bills'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Electricity'), 200);
    expect(find.text('Electricity'), findsOneWidget);
  });

  testWidgets('Home monthly bar shows the real over-budget amount',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    await settings.setMonthlyBudget(1000);
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final now = DateTime.now();
    await transactions.add(Tx(
      id: 'big',
      title: 'Big expense',
      amount: 1200,
      type: TxType.expense,
      categoryId: 'shopping',
      date: DateTime(now.year, now.month, now.day),
    ));
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();

    await tester.pumpWidget(await harness(
      storage: storage,
      settings: settings,
      transactions: transactions,
      upcoming: upcoming,
    ));
    await tester.pumpAndSettle();

    // Daily card flags the month as overspent.
    expect(find.textContaining('Month over'), findsOneWidget);
    // The old bar bug displayed "$0.00 over" because the leftover was clamped.
    await tester.scrollUntilVisible(
      find.textContaining('Budget exceeded by'),
      300,
    );
    expect(find.text(r'Budget exceeded by $200.00'), findsOneWidget);
  });

  testWidgets('Add button is available on Home but not in Settings',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();

    await tester.pumpWidget(await harness(
      storage: storage,
      settings: settings,
      transactions: transactions,
      upcoming: upcoming,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Planning'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Privacy & security'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Privacy & security'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
