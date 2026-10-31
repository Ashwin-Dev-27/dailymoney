/// An expected bill or recurring expense that has not been paid yet.
///
/// Upcoming items are deliberately simple: they are money you know is coming
/// out, so the daily budget engine can reserve it instead of treating it as
/// spendable cash.
class UpcomingExpense {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final DateTime dueDate;

  /// When true the item repeats every month on [dueDate]'s day-of-month.
  /// Marking it paid advances the date to the next occurrence.
  final bool repeatMonthly;
  final String note;

  const UpcomingExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.dueDate,
    this.repeatMonthly = false,
    this.note = '',
  });

  UpcomingExpense copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    DateTime? dueDate,
    bool? repeatMonthly,
    String? note,
  }) {
    return UpcomingExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      dueDate: dueDate ?? this.dueDate,
      repeatMonthly: repeatMonthly ?? this.repeatMonthly,
      note: note ?? this.note,
    );
  }

  factory UpcomingExpense.fromJson(Map<String, dynamic> json) {
    return UpcomingExpense(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      categoryId: (json['categoryId'] ?? 'bills').toString(),
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? '') ??
          DateTime.now(),
      repeatMonthly: json['repeatMonthly'] == true,
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
        'amount': amount,
        'categoryId': categoryId,
        'dueDate': dueDate.toIso8601String(),
        'repeatMonthly': repeatMonthly,
        'note': note,
      };

  @override
  bool operator ==(Object other) => other is UpcomingExpense && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The same day-of-month in a later month, clamped to that month's length.
DateTime addMonthsClamped(DateTime date, int months) {
  final index = date.year * 12 + date.month - 1 + months;
  final year = index ~/ 12;
  final month = index % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day.clamp(1, lastDay));
}
