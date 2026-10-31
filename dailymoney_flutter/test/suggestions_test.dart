import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/savings_goal.dart';
import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/models/upcoming_expense.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/services/storage_service.dart';
import 'package:dailymoney/services/suggestions.dart';

class Harness {
  Harness(this.settings, this.txs, this.upcoming, this.goals);

  final SettingsProvider settings;
  final TransactionsProvider txs;
  final UpcomingProvider upcoming;
  final GoalsProvider goals;

  static Future<Harness> create() async {
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
    return Harness(settings, txs, upcoming, goals);
  }

  List<Suggestion> build({DateTime? now}) => SuggestionEngine.build(
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        now: now ?? DateTime(2026, 10, 15, 10),
      );
}

Tx expense(String id, double amount, DateTime date,
        {String category = 'food'}) =>
    Tx(
      id: id,
      title: 'Expense $id',
      amount: amount,
      type: TxType.expense,
      categoryId: category,
      date: date,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('with no history or budget it asks for a budget', () async {
    final h = await Harness.create();

    final tips = h.build();

    expect(tips.map((t) => t.id), contains('set-budget'));
    expect(tips, hasLength(lessThanOrEqualTo(6)));
  });

  test('warns when the month is already overspent', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(1000);
    await h.txs.add(expense('big', 1500, DateTime(2026, 10, 10)));

    final tips = h.build();
    final ids = tips.map((t) => t.id).toList();

    expect(ids, contains('over-month'));
    expect(ids, isNot(contains('today-tight')));
    final over = tips.firstWhere((t) => t.id == 'over-month');
    expect(over.tone, SuggestionTone.warning);
    expect(over.body, contains(r'$500.00'));
  });

  test('flags a dominant category and a fast-rising one', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(4000);
    await h.txs.addAll([
      expense('food1', 400, DateTime(2026, 10, 12)),
      expense('shop1', 100, DateTime(2026, 10, 12), category: 'shopping'),
      expense('food0', 100, DateTime(2026, 9, 12)),
    ]);

    final tips = h.build();
    final ids = tips.map((t) => t.id).toList();

    expect(ids, contains('category-share-food'));
    expect(ids, contains('category-spike-food'));
    final share = tips.firstWhere((t) => t.id == 'category-share-food');
    expect(share.title, contains('80%'));
  });

  test('lists bills due in the next week with the amount set aside', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(3000);
    await h.upcoming.add(UpcomingExpense(
      id: 'power',
      title: 'Electricity',
      amount: 120,
      categoryId: 'utilities',
      dueDate: DateTime(2026, 10, 18),
    ));

    final tips = h.build();
    final bills = tips.firstWhere((t) => t.id == 'bills-week',
        orElse: () => throw StateError('bills-week missing'));

    expect(bills.title, '1 bill due this week');
    expect(bills.body, contains('Electricity'));
    expect(bills.body, contains(r'$120.00'));
  });

  test('nudges a nearly finished savings goal', () async {
    final h = await Harness.create();
    await h.goals.add(SavingsGoal(
      id: 'laptop',
      title: 'Laptop',
      target: 1000,
      saved: 800,
      targetDate: DateTime(2026, 12, 31),
    ));

    final tips = h.build();
    final goal = tips.firstWhere((t) => t.id == 'goal-close-laptop');

    expect(goal.title, 'Laptop is 80% funded');
    expect(goal.tone, SuggestionTone.positive);
    expect(goal.body, contains(r'$200.00'));
  });

  test('celebrates no-spend days and being ahead of plan', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(1000);
    await h.txs.add(expense('one', 100, DateTime(2026, 10, 2)));

    final tips = h.build(now: DateTime(2026, 10, 25, 10));
    final ids = tips.map((t) => t.id).toList();

    expect(ids, contains('no-spend'));
    expect(ids, contains('ahead'));
    expect(ids, contains('rolled-over'));
  });

  test('is capped at six actionable tips', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(1000);
    await h.txs.addAll([
      expense('a', 900, DateTime(2026, 10, 15)),
      expense('b', 300, DateTime(2026, 10, 15), category: 'shopping'),
    ]);
    await h.upcoming.add(UpcomingExpense(
      id: 'rent',
      title: 'Rent',
      amount: 100,
      categoryId: 'housing',
      dueDate: DateTime(2026, 10, 16),
    ));
    await h.goals.add(const SavingsGoal(
      id: 'g',
      title: 'Goal',
      target: 1000,
      saved: 900,
    ));

    final tips = h.build();

    expect(tips.length, lessThanOrEqualTo(6));
    expect(tips.map((t) => t.id).toSet().length, tips.length);
  });
}
