import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/savings_goal.dart';
import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/models/upcoming_expense.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/services/assistant_service.dart';
import 'package:dailymoney/services/storage_service.dart';

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

  AssistantReply ask(String question, {DateTime? now}) =>
      AssistantService.answer(
        question,
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        now: now ?? DateTime(2026, 10, 15, 10),
      );
}

Tx expense(String id, double amount, {String category = 'food'}) => Tx(
      id: id,
      title: 'Expense $id',
      amount: amount,
      type: TxType.expense,
      categoryId: category,
      date: DateTime(2026, 10, 15),
    );

void main() {
  test('empty question returns a snapshot with starter prompts', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(3100);

    final reply = h.ask('');

    expect(reply.text, contains('This month:'));
    expect(reply.text, contains('Today:'));
    expect(reply.followUps, isNotEmpty);
  });

  test('answers how much is left to spend today', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(3100);
    await h.txs.add(expense('lunch', 40));

    final reply = h.ask('How much can I spend today?');

    expect(reply.text, contains('You can spend'));
    expect(reply.text, contains('is already spent'));
    expect(reply.text, contains('days left this month'));
  });

  test('explains the allowance is missing without a budget', () async {
    final h = await Harness.create();

    final reply = h.ask('How much can I spend today?');

    expect(reply.text, contains('no monthly budget is set'));
  });

  test('reports the over-budget state for today', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(100);
    await h.txs.add(expense('big', 400));

    final reply = h.ask('How much can I spend today?');

    expect(reply.text, contains('over the allowance'));

    final why = h.ask('Why am I over budget?');
    expect(why.text, contains(r'$300.00 over'));
    expect(why.text, contains('Food'));
  });

  test('lists upcoming bills with due labels', () async {
    final h = await Harness.create();
    await h.upcoming.addAll([
      UpcomingExpense(
        id: 'rent',
        title: 'Rent',
        amount: 1200,
        categoryId: 'housing',
        dueDate: DateTime(2026, 10, 16),
      ),
      UpcomingExpense(
        id: 'power',
        title: 'Electricity',
        amount: 90,
        categoryId: 'utilities',
        dueDate: DateTime(2026, 10, 20),
      ),
    ]);

    final reply = h.ask('What bills are coming up?');

    expect(reply.text, contains('2 upcoming items'));
    expect(reply.text, contains('Rent'));
    expect(reply.text, contains('Electricity'));
    expect(reply.text, contains('set aside'));
  });

  test('breaks spending down by category', () async {
    final h = await Harness.create();
    await h.txs.addAll([
      expense('food', 300),
      expense('shop', 100, category: 'shopping'),
    ]);

    final reply = h.ask('Where is my money going?');

    expect(reply.text, contains(r'$400.00'));
    expect(reply.text, contains('Food'));
    expect(reply.text, contains('75%'));
  });

  test('summarises savings goals and monthly pace', () async {
    final h = await Harness.create();
    await h.goals.add(SavingsGoal(
      id: 'trip',
      title: 'Trip',
      target: 1200,
      saved: 300,
      targetDate: DateTime(2027, 1, 1),
    ));

    final reply = h.ask('How are my savings goals doing?');

    expect(reply.text, contains('Trip'));
    expect(reply.text, contains(r'$300.00 of $1,200.00'));
    expect(reply.text, contains('25%'));
    expect(reply.text, contains('about'));
  });

  test('greets the user by name and lists what it can do', () async {
    final h = await Harness.create();
    await h.settings.setUserName('Ashwin');

    expect(h.ask('hello').text, contains('Hello, Ashwin!'));

    final help = h.ask('What can you do?');
    expect(help.text, contains('own records'));
    expect(help.followUps, isNotEmpty);
  });

  test('falls back to a snapshot for unrecognised questions', () async {
    final h = await Harness.create();
    await h.settings.setMonthlyBudget(500);
    await h.txs.add(expense('coffee', 20));

    final reply = h.ask('Tell me a joke');

    expect(reply.text, contains('This month:'));
    expect(reply.text, contains('Try asking'));
    expect(reply.followUps, isNotEmpty);
  });

  test('answers balance and income questions from the ledger', () async {
    final h = await Harness.create();
    await h.txs.addAll([
      Tx(
        id: 'salary',
        title: 'Salary',
        amount: 5000,
        type: TxType.income,
        categoryId: 'salary',
        date: DateTime(2026, 10, 1),
      ),
      expense('food', 200),
    ]);

    final balance = h.ask('What is my balance?');
    expect(balance.text, contains(r'$4,800.00'));

    final income = h.ask("How much have I earned?");
    expect(income.text, contains(r'$5,000.00'));
    expect(income.text, contains('you kept'));
  });
}
