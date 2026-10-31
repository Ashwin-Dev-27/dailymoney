import 'dart:math' as math;

/// A deterministic recovery plan suggestion.
class RecoverySuggestion {
  const RecoverySuggestion({
    required this.overspend,
    required this.dailyCut,
    required this.days,
    required this.daysLeft,
    required this.realistic,
  });

  final double overspend;
  final double dailyCut;
  final int days;
  final int daysLeft;
  final bool realistic;

  bool get isNeeded => overspend > 0.005;

  double get covered => dailyCut * days;
}

/// Rule-based recovery maths. No AI arithmetic and no shaming language.
class RecoveryPlanner {
  const RecoveryPlanner._();

  static RecoverySuggestion suggest({
    required double overspend,
    required int daysLeft,
    required double dailyAllowance,
  }) {
    final over = math.max(0.0, overspend);
    final left = math.max(1, daysLeft);
    if (over <= 0.005) {
      return RecoverySuggestion(
        overspend: 0,
        dailyCut: 0,
        days: 0,
        daysLeft: left,
        realistic: true,
      );
    }

    // Spread the gap over at most two weeks so the plan feels achievable.
    final window = math.min(left, 14);
    var cut = over / window;
    // Round up to whole currency units.
    cut = cut.ceilToDouble();
    var days = window;

    // Do not ask for more than half of the daily plan unless there is no
    // allowance to protect. Essentials are never targeted by this engine.
    if (dailyAllowance > 0) {
      final maxCut = math.max(1.0, dailyAllowance * 0.5);
      if (cut > maxCut) {
        cut = maxCut;
        days = math.min(60, math.max(window, (over / cut).ceil()));
      }
    }

    return RecoverySuggestion(
      overspend: over,
      dailyCut: cut,
      days: days,
      daysLeft: left,
      realistic: cut * days >= over - 0.005,
    );
  }

  /// The allowance after a plan's daily cut, never below zero.
  static double allowanceAfter(double allowance, double dailyCut) =>
      math.max(0.0, allowance - math.max(0.0, dailyCut));

  /// How much of the overspend a custom plan covers.
  static double coverage(double dailyCut, int days) =>
      math.max(0.0, dailyCut) * math.max(0, days);
}
