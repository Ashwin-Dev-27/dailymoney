import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/category.dart';
import 'package:dailymoney/models/expected_income.dart';
import 'package:dailymoney/models/savings_goal.dart';
import 'package:dailymoney/models/shared_expense.dart';
import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/providers/expected_income_provider.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/shared_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/services/briefings.dart';
import 'package:dailymoney/services/habits.dart';
import 'package:dailymoney/services/leaks.dart';
import 'package:dailymoney/services/missing_expense.dart';
import 'package:dailymoney/services/money_plan.dart';
import 'package:dailymoney/services/recovery.dart';
import 'package:dailymoney/services/storage_service.dart';
import 'package:dailymoney/services/what_if.dart';

Tx expense(
  String id,
  double amount,
  DateTime date, {
  double? personalShare,
}) =>
    Tx(
      id: id,
      title: 'Expense $id',
      amount: amount,
      type: TxType.expense,
      categoryId: 'food',
      date: date,
      personalShare: personalShare,
    );

Tx income(String id, double amount, DateTime date) => Tx(
      id: id,
      title: 'Income $id',
      amount: amount,
      type: TxType.income,
      categoryId: 'salary',
      date: date,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late SettingsProvider settings;
  late TransactionsProvider txs;
  late UpcomingProvider upcoming;
  late GoalsProvider goals;
  late SharedProvider shared;
  late ExpectedIncomeProvider expected;
  final today = DateTime(2026, 10, 1, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    settings = SettingsProvider(storage);
    await settings.load();
    txs = TransactionsProvider(storage);
    await txs.load();
    upcoming = UpcomingProvider(storage);
    await upcoming.load();
    goals = GoalsProvider(storage);
    await goals.load();
    shared = SharedProvider(storage);
    await shared.load();
    expected = ExpectedIncomeProvider(storage);
    await expected.load();
    await settings.setMonthlyBudget(3100);
  });

  group('shared and settlement money', () {
    test('only the personal share counts as spending', () {
      return () async {
        await txs.add(expense(
          'meal',
          900,
          today,
          personalShare: 300,
        ));
        final totals = txs.totalsFor(today);
        expect(totals.expense, 300);
        expect(txs.balance, -900);
      }();
    });

    test('settlement income changes balance but never income totals', () async {
      await txs.add(income('salary', 1000, today));
      await txs.add(Tx(
        id: 'repayment',
        title: 'Received · dinner',
        amount: 600,
        type: TxType.income,
        categoryId: 'other-income',
        date: today,
        isSettlement: true,
      ));

      expect(txs.balance, 1600);
      expect(txs.totalsFor(today).income, 1000);
    });

    test('syncing a split expense creates and updates its shared record',
        () async {
      final tx = expense('dinner', 900, today, personalShare: 300);
      await txs.add(tx);
      await shared.syncForTransaction(tx);

      expect(shared.all, hasLength(1));
      final record = shared.all.single;
      expect(record.total, 900);
      expect(record.myShare, 300);
      expect(record.outstanding, 600);
      expect(shared.owedToMe, 600);

      final updated = tx.copyWith(personalShare: 400);
      await txs.update(updated);
      await shared.syncForTransaction(updated);
      expect(shared.all.single.myShare, 400);
      expect(shared.owedToMe, 500);

      await shared.removeForTransaction(tx, txs);
      expect(shared.isEmpty, isTrue);
    });

    test('receiving a repayment settles the debt without new income', () async {
      final tx = expense('trip', 1200, today, personalShare: 400);
      await txs.add(tx);
      await shared.syncForTransaction(tx);

      final settlement = await shared.settle(
        shared.all.single,
        800,
        txs,
        now: today,
      );

      expect(settlement, isNotNull);
      expect(settlement!.isSettlement, isTrue);
      expect(shared.all.single.outstanding, 0);
      expect(txs.totalsFor(today).income, 0);
      expect(txs.balance, -400);
    });

    test('paying someone back is a real expense', () async {
      final record = SharedExpense(
        id: 'owed',
        title: 'Concert',
        total: 500,
        myShare: 500,
        direction: SharedDirection.iOwe,
        date: today,
      );
      await shared.add(record);

      final payment = await shared.settle(record, 200, txs, now: today);

      expect(payment, isNotNull);
      expect(payment!.isSettlement, isFalse);
      expect(txs.totalsFor(today).expense, 200);
      expect(shared.iOwe, 300);
    });

    test('editing a settlement keeps the shared record in step', () async {
      final tx = expense('dinner', 900, today, personalShare: 300);
      await txs.add(tx);
      await shared.syncForTransaction(tx);

      final receipt = await shared.settle(
        shared.all.single,
        600,
        txs,
        now: today,
      );
      expect(receipt, isNotNull);
      final recordId = shared.all.single.id;
      expect(receipt!.settlementOf, recordId);
      expect(shared.all.single.outstanding, 0);

      final edited = receipt.copyWith(amount: 200);
      await txs.update(edited);
      await shared.syncForTransaction(edited, previous: receipt);

      expect(shared.all.single.settled, 200);
      expect(shared.all.single.outstanding, 400);

      await shared.removeForTransaction(edited, txs);
      expect(shared.all.single.settled, 0);
      expect(shared.all.single.outstanding, 600);
    });

    test('deleting a settled split removes its repayments too', () async {
      final tx = expense('holiday', 1000, today, personalShare: 400);
      await txs.add(tx);
      await shared.syncForTransaction(tx);
      final receipt = await shared.settle(
        shared.all.single,
        600,
        txs,
        now: today,
      );
      expect(receipt, isNotNull);
      expect(txs.balance, -400);

      await txs.remove(tx.id);
      await shared.removeForTransaction(tx, txs);

      expect(shared.isEmpty, isTrue);
      expect(txs.all.any((t) => t.id == receipt!.id), isFalse);
      expect(txs.all.any((t) => t.id == tx.id), isFalse);
      expect(txs.balance, 0);
    });

    test('deleting a payback restores the payable', () async {
      final record = SharedExpense(
        id: 'owed-delete',
        title: 'Concert',
        total: 500,
        myShare: 500,
        direction: SharedDirection.iOwe,
        date: today,
      );
      await shared.add(record);
      final payment = await shared.settle(record, 200, txs, now: today);

      expect(shared.iOwe, 300);
      await shared.removeForTransaction(payment!, txs);
      expect(shared.iOwe, 500);
    });
  });

  group('expected income', () {
    test('stays outside the balance until marked received', () async {
      final item = ExpectedIncome(
        id: 'stipend',
        title: 'Scholarship',
        amount: 2500,
        expectedDate: today.add(const Duration(days: 5)),
        categoryId: 'scholarship',
      );
      await expected.add(item);
      expect(expected.pendingTotal, 2500);
      expect(txs.balance, 0);
      expect(txs.isEmpty, isTrue);

      final tx = await expected.markReceived(item, txs, now: today);

      expect(tx, isNotNull);
      expect(txs.balance, 2500);
      expect(txs.totalsFor(today).income, 2500);
      expect(expected.pending, isEmpty);
      expect(expected.received, hasLength(1));
      expect(await expected.markReceived(item, txs, now: today), isNull);
    });
  });

  group('money plan', () {
    test('protection caps the allowance at confirmed safe money', () async {
      await txs.add(income('small', 100, today));
      final plan = MoneyPlan.compute(
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        today: today,
      );

      expect(plan.hasConfirmedBalance, isTrue);
      expect(plan.safeToSpend, 100);
      expect(plan.snapshot.protectionApplied, isTrue);
      expect(plan.snapshot.allowance, lessThan(100));
    });

    test('without a confirmed balance the budget plan is used', () async {
      await txs.add(expense('cash', 200, today));
      final plan = MoneyPlan.compute(
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        today: today,
      );

      expect(plan.hasConfirmedBalance, isFalse);
      expect(plan.snapshot.safeToSpend, isNull);
      expect(plan.snapshot.protectionApplied, isFalse);
      expect(plan.snapshot.allowance, greaterThan(0));
    });

    test('dated savings goals become a protected monthly commitment', () async {
      final goal = SavingsGoal(
        id: 'laptop',
        title: 'Laptop',
        target: 3000,
        saved: 0,
        targetDate: DateTime(2026, 12, 1),
      );
      await goals.add(goal);

      final commitment = MoneyPlan.savingsCommitmentFor(goals, today);
      expect(commitment, closeTo(goal.monthlyNeeded(today), 0.001));
      expect(commitment, greaterThan(0));

      await txs.add(income('salary', 5000, today));
      final plan = MoneyPlan.compute(
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        today: today,
      );
      expect(plan.savingsCommitment, commitment);
      expect(plan.snapshot.protectedSavings, commitment);
      expect(
        plan.safeToSpend,
        closeTo(5000 - commitment, 0.001),
      );
    });
  });

  group('purchase checks', () {
    test('classifies a purchase against today, the month and the balance',
        () async {
      await txs.add(income('salary', 5000, today));
      final plan = MoneyPlan.compute(
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        today: today,
      );

      final small = WhatIfEngine.assessPurchase(
        price: 1,
        snapshot: plan.snapshot,
        plan: plan,
      );
      final mid = WhatIfEngine.assessPurchase(
        price: 4000,
        snapshot: plan.snapshot,
        plan: plan,
      );
      final huge = WhatIfEngine.assessPurchase(
        price: 6000,
        snapshot: plan.snapshot,
        plan: plan,
      );

      expect(small.status, Affordability.fitsToday);
      expect(mid.status, Affordability.tight);
      expect(huge.status, Affordability.notCovered);
    });
  });

  group('recovery planning', () {
    test('spreads the overspend over at most two weeks', () {
      final suggestion = RecoveryPlanner.suggest(
        overspend: 500,
        daysLeft: 20,
        dailyAllowance: 100,
      );

      expect(suggestion.days, 14);
      expect(suggestion.dailyCut, 36);
      expect(suggestion.covered, greaterThanOrEqualTo(500));
      expect(suggestion.realistic, isTrue);
    });

    test('never asks for more than half the daily allowance', () {
      final suggestion = RecoveryPlanner.suggest(
        overspend: 5000,
        daysLeft: 20,
        dailyAllowance: 100,
      );

      expect(suggestion.dailyCut, 50);
      expect(suggestion.days, 60);
      expect(suggestion.realistic, isFalse);
    });
  });

  group('patterns', () {
    test('insufficient history produces no leak or habit claims', () {
      final few = [
        expense('one', 50, today),
        expense('two', 50, today.subtract(const Duration(days: 2))),
      ];
      expect(
        LeakDetector.build(
          transactions: few,
          settings: settings,
          now: today,
        ),
        isEmpty,
      );
      expect(
        HabitEngine.build(
          transactions: few,
          settings: settings,
          now: today,
        ),
        isEmpty,
      );
    });

    test('repeated identical entries are offered as a possible duplicate',
        () async {
      final txs = <Tx>[];
      for (var i = 0; i < 18; i++) {
        txs.add(expense(
          'unique$i',
          50.0 + i,
          today.subtract(Duration(days: i)),
        ));
      }
      // Same display title and amount within 36 hours: a possible duplicate.
      txs.add(Tx(
        id: 'coffee1',
        title: 'Coffee',
        amount: 50,
        type: TxType.expense,
        categoryId: 'food',
        date: today,
      ));
      txs.add(Tx(
        id: 'coffee2',
        title: 'Coffee',
        amount: 50,
        type: TxType.expense,
        categoryId: 'food',
        date: today.subtract(const Duration(days: 1)),
      ));

      final insights = LeakDetector.build(
        transactions: txs,
        settings: settings,
        now: today,
      );
      expect(insights.any((i) => i.kind == LeakKind.duplicate), isTrue);
      expect(
        insights
            .where((i) => i.kind == LeakKind.duplicate)
            .every((i) => i.evidence.length >= 2),
        isTrue,
      );
    });
  });

  group('missing expense prompt', () {
    test('asks after a quiet evening only when there is a real baseline',
        () async {
      for (var i = 2; i <= 5; i++) {
        await txs.add(expense(
          'day$i',
          100,
          today.subtract(Duration(days: i)),
        ));
      }
      final check = MissingExpenseDetector.check(
        transactions: txs.all,
        settings: settings,
        now: DateTime(2026, 10, 1, 18),
      );
      expect(check.shouldAsk, isTrue);

      await settings.dismissMissingExpense(DateTime(2026, 10, 1, 18));
      final dismissed = MissingExpenseDetector.check(
        transactions: txs.all,
        settings: settings,
        now: DateTime(2026, 10, 1, 18),
      );
      expect(dismissed.shouldAsk, isFalse);
    });

    test('stays quiet before the evening', () async {
      final check = MissingExpenseDetector.check(
        transactions: txs.all,
        settings: settings,
        now: DateTime(2026, 10, 1, 10),
      );
      expect(check.shouldAsk, isFalse);
    });
  });

  test('student categories exist for both money directions', () {
    final incomeIds = categoriesFor(TxType.income).map((c) => c.id).toSet();
    final expenseIds = categoriesFor(TxType.expense).map((c) => c.id).toSet();
    expect(incomeIds, containsAll(['pocket-money', 'scholarship']));
    expect(expenseIds, containsAll(['hostel', 'study']));
  });

  group('briefings', () {
    test('morning uses confirmed numbers only', () {
      final plan = MoneyPlan.compute(
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        today: today,
      );
      final briefing = Briefings.morning(
        settings: settings,
        snapshot: plan.snapshot,
        upcoming: upcoming,
        expected: expected,
        now: DateTime(2026, 10, 1, 8),
      );
      expect(briefing.title, 'Good morning!');
      expect(briefing.body, contains('You can spend \$100.00 today.'));
      expect(briefing.body, contains('\$3,100.00 left this month.'));
      expect(briefing.body, isNot(contains('not counted')));
    });

    test('night marks a no-spend day and the allowance left', () {
      final plan = MoneyPlan.compute(
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        today: today,
      );
      final briefing = Briefings.night(
        settings: settings,
        snapshot: plan.snapshot,
        upcoming: upcoming,
        shared: shared,
        expected: expected,
        now: DateTime(2026, 10, 1, 21),
      );
      expect(briefing.title, "Tonight's spending summary");
      expect(
        briefing.body,
        contains('No spending recorded — that is a no-spend day.'),
      );
      expect(
          briefing.body, contains('\$100.00 of today\'s allowance is left.'));
    });
  });
}
