import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/savings_goal.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/services/storage_service.dart';

Future<GoalsProvider> emptyProvider() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final goals = GoalsProvider(storage);
  await goals.load();
  return goals;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('goal maths: progress, remaining and completion', () {
    const goal = SavingsGoal(
      id: 'g1',
      title: 'Emergency fund',
      target: 10000,
      saved: 2500,
    );

    expect(goal.progress, 0.25);
    expect(goal.remaining, 7500);
    expect(goal.isComplete, isFalse);

    const complete =
        SavingsGoal(id: 'g2', title: 'Done', target: 100, saved: 120);
    expect(complete.progress, 1);
    expect(complete.remaining, 0);
    expect(complete.isComplete, isTrue);
  });

  test('goal without a target never divides by zero', () {
    const goal = SavingsGoal(id: 'g', title: 'Open', target: 0, saved: 50);
    expect(goal.progress, 0);
    expect(goal.remaining, 0);
    expect(goal.isComplete, isFalse);
  });

  test('monthlyNeeded spreads the remainder across whole months', () {
    final goal = SavingsGoal(
      id: 'trip',
      title: 'Trip',
      target: 12000,
      saved: 3000,
      targetDate: DateTime(2027, 1, 1),
    );

    // From October 2026 there are three months left (Oct, Nov, Dec).
    expect(goal.monthsLeft(DateTime(2026, 10, 15)), 3);
    expect(goal.monthlyNeeded(DateTime(2026, 10, 15)), 3000);

    // A target later in the month than "today" still counts that month.
    expect(
      SavingsGoal(
        id: 'late',
        title: 'Late',
        target: 100,
        saved: 0,
        targetDate: DateTime(2026, 10, 20),
      ).monthsLeft(DateTime(2026, 10, 15)),
      1,
    );
  });

  test('overdue ignores complete goals and compares whole days', () {
    final overdue = SavingsGoal(
      id: 'o',
      title: 'Overdue',
      target: 500,
      saved: 100,
      targetDate: DateTime(2026, 10, 14),
    );
    expect(overdue.isOverdue(DateTime(2026, 10, 15, 22)), isTrue);
    expect(overdue.isOverdue(DateTime(2026, 10, 14, 23)), isFalse);

    final complete = SavingsGoal(
      id: 'c',
      title: 'Complete',
      target: 100,
      saved: 100,
      targetDate: DateTime(2026, 1, 1),
    );
    expect(complete.isOverdue(DateTime(2026, 10, 15)), isFalse);
  });

  test('provider adds, contributes, clamps withdrawals and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final goals = GoalsProvider(storage);
    await goals.load();

    await goals.add(const SavingsGoal(
      id: 'g1',
      title: 'Laptop',
      target: 2000,
      targetDate: null,
    ));
    await goals.contribute('g1', 500);
    expect(goals.totalSaved, 500);
    expect(goals.totalTarget, 2000);
    expect(goals.totalRemaining, 1500);

    await goals.contribute('g1', -900);
    expect(goals.all.single.saved, 0, reason: 'never goes below zero');

    await goals.contribute('g1', 250);
    await goals.update(goals.all.single.copyWith(title: 'New laptop'));
    expect(goals.all.single.title, 'New laptop');

    // A fresh provider reads the same encrypted-or-plain payload back.
    final reloaded = GoalsProvider(storage);
    await reloaded.load();
    expect(reloaded.count, 1);
    expect(reloaded.all.single.saved, 250);
    expect(reloaded.all.single.title, 'New laptop');
  });

  test('active goals sort before completed ones and by target date', () async {
    final goals = await emptyProvider();

    await goals.addAll([
      SavingsGoal(
        id: 'done',
        title: 'Done',
        target: 100,
        saved: 100,
        targetDate: DateTime(2026, 1, 1),
      ),
      SavingsGoal(
        id: 'later',
        title: 'Later',
        target: 100,
        targetDate: DateTime(2027, 6, 1),
      ),
      SavingsGoal(
        id: 'sooner',
        title: 'Sooner',
        target: 100,
        targetDate: DateTime(2026, 12, 1),
      ),
      const SavingsGoal(id: 'open', title: 'Open-ended', target: 100),
    ]);

    expect(goals.all.map((g) => g.id), ['sooner', 'later', 'open', 'done']);
    expect(goals.nextGoal?.id, 'sooner');
    expect(goals.active, hasLength(3));

    await goals.contribute('sooner', 100);
    expect(goals.nextGoal?.id, 'later');
  });

  test('remove and clear keep storage in sync', () async {
    final goals = await emptyProvider();
    await goals.addAll(const [
      SavingsGoal(id: 'a', title: 'A', target: 10),
      SavingsGoal(id: 'b', title: 'B', target: 10),
    ]);

    await goals.remove('a');
    expect(goals.count, 1);
    expect(goals.all.single.id, 'b');

    await goals.clear();
    expect(goals.isEmpty, isTrue);
    expect(goals.totalSaved, 0);
    expect(goals.nextGoal, isNull);
  });

  test('goals survive a JSON round trip', () {
    final goal = SavingsGoal(
      id: 'json',
      title: 'Round trip',
      target: 999.99,
      saved: 12.5,
      targetDate: DateTime(2027, 3, 4),
      note: 'keep going',
    );

    final copy = SavingsGoal.fromJson(goal.toJson());

    expect(copy.id, goal.id);
    expect(copy.title, goal.title);
    expect(copy.target, goal.target);
    expect(copy.saved, goal.saved);
    expect(copy.targetDate, goal.targetDate);
    expect(copy.note, goal.note);
  });
}
