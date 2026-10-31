import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/shared_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/screens/add_edit_sheet.dart';
import 'package:dailymoney/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('changing a settlement to an expense clears settlement state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();

    final settings = SettingsProvider(storage);
    await settings.load();
    final txs = TransactionsProvider(storage);
    await txs.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();
    final goals = GoalsProvider(storage);
    await goals.load();
    final shared = SharedProvider(storage);
    await shared.load();

    final today = DateTime.now();
    final dinner = Tx(
      id: 'dinner',
      title: 'Dinner',
      amount: 900,
      type: TxType.expense,
      categoryId: 'food',
      date: today,
      personalShare: 300,
    );
    await txs.add(dinner);
    await shared.syncForTransaction(dinner);
    final receipt = await shared.settle(
      shared.all.single,
      600,
      txs,
      now: today,
    );
    expect(receipt, isNotNull);
    expect(receipt!.isSettlement, isTrue);
    expect(receipt.settlementOf, shared.all.single.id);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: txs),
          ChangeNotifierProvider.value(value: upcoming),
          ChangeNotifierProvider.value(value: goals),
          ChangeNotifierProvider.value(value: shared),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddEditSheet(existing: receipt),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);

    // Switch the repayment to an ordinary expense.
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    expect(find.text('Split with someone'), findsOneWidget);

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final saved = txs.all.firstWhere((tx) => tx.id == receipt.id);
    expect(saved.type, TxType.expense);
    expect(saved.isSettlement, isFalse);
    expect(saved.settlementOf, isNull);
    expect(txs.totalsFor(today).income, 0);
    expect(shared.all.single.settled, 0);
    expect(shared.all.single.outstanding, 600);
  });
}
