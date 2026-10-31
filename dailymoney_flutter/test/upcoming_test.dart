import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/models/upcoming_expense.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/services/storage_service.dart';

UpcomingExpense bill({
  required String id,
  double amount = 50,
  DateTime? due,
  bool monthly = false,
}) =>
    UpcomingExpense(
      id: id,
      title: 'Bill $id',
      amount: amount,
      categoryId: 'bills',
      dueDate: due ?? DateTime(2026, 10, 20),
      repeatMonthly: monthly,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late UpcomingProvider upcoming;
  late TransactionsProvider txs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    upcoming = UpcomingProvider(storage);
    await upcoming.load();
    txs = TransactionsProvider(storage);
    await txs.load();
  });

  group('UpcomingProvider', () {
    test('persists items across reloads', () async {
      await upcoming.add(bill(id: 'a', amount: 12.5));
      await upcoming.addAll([
        bill(id: 'b', amount: 99),
        bill(id: 'c', amount: 7, monthly: true),
      ]);
      expect(upcoming.count, 3);

      final reloaded = UpcomingProvider(storage);
      await reloaded.load();
      expect(reloaded.count, 3);
      expect(reloaded.all.map((e) => e.id).toSet(), {'a', 'b', 'c'});
    });

    test('sorted by due date and nextUpcoming limits the preview', () async {
      await upcoming.addAll([
        bill(id: 'late', due: DateTime(2026, 11, 5)),
        bill(id: 'soon', due: DateTime(2026, 10, 2)),
        bill(id: 'middle', due: DateTime(2026, 10, 20)),
      ]);

      expect(
          upcoming.all.map((e) => e.id).toList(), ['soon', 'middle', 'late']);
      expect(upcoming.nextUpcoming(limit: 2).map((e) => e.id).toList(),
          ['soon', 'middle']);
    });

    test('one-time bills count from their due date onward', () async {
      await upcoming.addAll([
        bill(id: 'oct', amount: 100, due: DateTime(2026, 10, 20)),
        bill(id: 'nov', amount: 300, due: DateTime(2026, 11, 1)),
      ]);

      expect(upcoming.reservedForMonth(DateTime(2026, 10)), 100);
      // The October bill is still unpaid, so November keeps it reserved too.
      expect(upcoming.reservedForMonth(DateTime(2026, 11)), 400);
    });

    test('recurring bills stay reserved while overdue', () async {
      await upcoming.addAll([
        bill(
          id: 'overdue',
          amount: 80,
          due: DateTime(2026, 8, 4),
          monthly: true,
        ),
        bill(
          id: 'this-month',
          amount: 40,
          due: DateTime(2026, 10, 9),
          monthly: true,
        ),
        bill(
          id: 'future',
          amount: 500,
          due: DateTime(2026, 12, 1),
          monthly: true,
        ),
      ]);

      expect(upcoming.reservedForMonth(DateTime(2026, 10)), 120);
      expect(upcoming.reservedForMonth(DateTime(2026, 9)), 80);
      expect(upcoming.reservedForMonth(DateTime(2026, 11)), 120);
    });

    test('remove and clear update storage', () async {
      await upcoming.addAll([bill(id: 'a'), bill(id: 'b')]);
      await upcoming.remove('a');
      expect(upcoming.count, 1);

      final removed = await upcoming.removeAll();
      expect(removed, 1);
      expect(upcoming.isEmpty, isTrue);

      final reloaded = UpcomingProvider(storage);
      await reloaded.load();
      expect(reloaded.isEmpty, isTrue);
    });
  });

  group('markPaid', () {
    test('one-time bill becomes an expense and disappears', () async {
      await upcoming
          .add(bill(id: 'one', amount: 120, due: DateTime(2026, 10, 5)));

      final created = await upcoming.markPaid(upcoming.all.first, txs);

      expect(created.type, TxType.expense);
      expect(created.amount, 120);
      expect(created.title, 'Bill one');
      expect(txs.count, 1);
      expect(upcoming.isEmpty, isTrue);

      final reloadedTx = TransactionsProvider(storage);
      await reloadedTx.load();
      expect(reloadedTx.count, 1);
    });

    test('recurring bill advances past today and stays tracked', () async {
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, 1);
      await upcoming.add(
        bill(id: 'rent', amount: 900, due: due, monthly: true),
      );

      final created = await upcoming.markPaid(upcoming.all.first, txs);

      expect(created.amount, 900);
      expect(txs.count, 1);
      expect(upcoming.count, 1);
      final renewed = upcoming.all.first;
      expect(renewed.id, 'rent');
      final today = DateTime(now.year, now.month, now.day);
      expect(renewed.dueDate.isBefore(today), isFalse);
      // It must be a different occurrence, not the one just paid.
      expect(renewed.dueDate, isNot(due));
    });
  });
}
