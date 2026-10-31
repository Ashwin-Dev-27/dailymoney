import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/screens/reports_screen.dart';
import 'package:dailymoney/services/storage_service.dart';
import 'package:dailymoney/theme.dart';
import 'package:dailymoney/utils/format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reports render monthly performance and daily rows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    await settings.setMonthlyBudget(3100);
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final now = DateTime.now();
    await transactions.addAll([
      Tx(
        id: 'salary',
        title: 'Salary',
        amount: 4200,
        type: TxType.income,
        categoryId: 'salary',
        date: DateTime(now.year, now.month, 1),
      ),
      Tx(
        id: 'lunch',
        title: 'Lunch',
        amount: 25,
        type: TxType.expense,
        categoryId: 'food',
        date: DateTime(now.year, now.month, now.day),
      ),
    ]);
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
          home: ReportsScreen(initialMonth: monthOf(now)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Month performance'), findsOneWidget);
    expect(find.text('Daily breakdown'), findsOneWidget);
    expect(find.text(monthLabel(monthOf(now))), findsOneWidget);
    expect(find.text('Spent days'), findsOneWidget);
    // The salary-only day is not a spent day.
    expect(find.text('1'), findsOneWidget);

    // Moving back a month updates the header and returns a full month.
    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await tester.pumpAndSettle();
    expect(
      find.text(monthLabel(monthAdd(monthOf(now), -1))),
      findsOneWidget,
    );

    // Back to the current month: show the report, then scroll to today's row.
    await tester.tap(find.byIcon(LucideIcons.chevronRight));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsNothing); // amounts, not titles
    await tester.scrollUntilVisible(find.text('-\$25.00'), 200);
    expect(find.text('-\$25.00'), findsOneWidget);
  });
}
