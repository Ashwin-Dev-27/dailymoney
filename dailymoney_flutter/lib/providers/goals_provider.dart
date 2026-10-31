import 'package:flutter/foundation.dart';

import '../models/savings_goal.dart';
import '../services/storage_service.dart';

/// Savings goals shown on Home and the dedicated Goals screen.
class GoalsProvider extends ChangeNotifier {
  GoalsProvider(this._storage);

  final StorageService _storage;
  final List<SavingsGoal> _goals = [];

  /// Active goals first (soonest target date), completed goals last.
  List<SavingsGoal> get all {
    final list = List<SavingsGoal>.from(_goals)
      ..sort((a, b) {
        if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
        final ad = a.targetDate;
        final bd = b.targetDate;
        if (ad == null && bd == null) return a.title.compareTo(b.title);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    return List.unmodifiable(list);
  }

  List<SavingsGoal> get active => all.where((g) => !g.isComplete).toList();

  bool get isEmpty => _goals.isEmpty;
  int get count => _goals.length;

  double get totalSaved => _goals.fold(0.0, (sum, goal) => sum + goal.saved);

  double get totalTarget => _goals.fold(0.0, (sum, goal) => sum + goal.target);

  double get totalRemaining =>
      _goals.fold(0.0, (sum, goal) => sum + goal.remaining);

  SavingsGoal? get nextGoal => active.isEmpty ? null : active.first;

  Future<void> load() async {
    _goals
      ..clear()
      ..addAll(await _storage.loadGoals());
    notifyListeners();
  }

  Future<void> add(SavingsGoal goal) async {
    _goals.add(goal);
    notifyListeners();
    await _storage.saveGoals(_goals);
  }

  Future<void> addAll(List<SavingsGoal> goals) async {
    _goals.addAll(goals);
    notifyListeners();
    await _storage.saveGoals(_goals);
  }

  Future<void> update(SavingsGoal goal) async {
    final i = _goals.indexWhere((g) => g.id == goal.id);
    if (i < 0) return add(goal);
    _goals[i] = goal;
    notifyListeners();
    await _storage.saveGoals(_goals);
  }

  Future<void> remove(String id) async {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
    await _storage.saveGoals(_goals);
  }

  /// Adds [amount] to a goal; a negative amount withdraws, never below zero.
  Future<void> contribute(String id, double amount) async {
    final i = _goals.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final current = _goals[i];
    final saved = (current.saved + amount).clamp(0.0, double.infinity);
    _goals[i] = current.copyWith(saved: saved.toDouble());
    notifyListeners();
    await _storage.saveGoals(_goals);
  }

  Future<void> clear() async {
    _goals.clear();
    notifyListeners();
    await _storage.saveGoals(_goals);
  }
}
