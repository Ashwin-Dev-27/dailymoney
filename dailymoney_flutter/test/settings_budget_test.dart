import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/app.dart';
import 'package:dailymoney/providers/capture_provider.dart';
import 'package:dailymoney/providers/expected_income_provider.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/providers/security_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/shared_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/services/storage_service.dart';

/// The Settings budget field must keep decimals instead of stripping the dot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings budget accepts grouped and decimal-comma amounts',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    await settings.dismissWelcome();
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();
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

    await tester.pumpWidget(
      MultiProvider(
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final budgetField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'None',
    );
    expect(budgetField, findsOneWidget);

    await tester.enterText(budgetField, '1,234.50');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.monthlyBudget, 1234.5);

    await tester.enterText(budgetField, '12,50');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.monthlyBudget, 12.5);

    // An unparseable value must not silently wipe the saved budget.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pumpAndSettle();
    await tester.enterText(budgetField, '1.2.3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.monthlyBudget, 12.5);
    expect(find.text('Enter a valid budget amount'), findsOneWidget);
  });
}
