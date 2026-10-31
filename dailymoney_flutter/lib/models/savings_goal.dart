import 'dart:math' as math;

/// A savings target the user is putting money aside for.
class SavingsGoal {
  final String id;
  final String title;
  final double target;
  final double saved;
  final DateTime? targetDate;
  final String note;

  const SavingsGoal({
    required this.id,
    required this.title,
    required this.target,
    this.saved = 0,
    this.targetDate,
    this.note = '',
  });

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);

  double get remaining => math.max(0.0, target - saved);

  bool get isComplete => target > 0 && saved >= target;

  /// True when the goal is incomplete and its target date is in the past.
  bool isOverdue(DateTime now) {
    final date = targetDate;
    if (date == null || isComplete) return false;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(date.year, date.month, date.day);
    return due.isBefore(today);
  }

  /// Monthly amount needed to finish on time, using whole months from [from].
  double monthlyNeeded(DateTime from) {
    if (isComplete) return 0;
    final date = targetDate;
    if (date == null) return remaining;

    var months = (date.year - from.year) * 12 + date.month - from.month;
    if (date.day > from.day) months += 1;
    return remaining / math.max(1, months);
  }

  /// Months left until [targetDate] (at least 1). Null when open-ended.
  int? monthsLeft(DateTime from) {
    final date = targetDate;
    if (date == null) return null;
    var months = (date.year - from.year) * 12 + date.month - from.month;
    if (date.day > from.day) months += 1;
    return math.max(1, months);
  }

  SavingsGoal copyWith({
    String? id,
    String? title,
    double? target,
    double? saved,
    DateTime? targetDate,
    String? note,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      target: target ?? this.target,
      saved: saved ?? this.saved,
      targetDate: targetDate ?? this.targetDate,
      note: note ?? this.note,
    );
  }

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      target: _toDouble(json['target']),
      saved: _toDouble(json['saved']),
      targetDate: DateTime.tryParse(json['targetDate']?.toString() ?? ''),
      note: (json['note'] ?? '').toString(),
    );
  }

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'target': target,
        'saved': saved,
        'targetDate': targetDate?.toIso8601String(),
        'note': note,
      };

  @override
  bool operator ==(Object other) => other is SavingsGoal && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
