/// How sure the user is that this money will arrive.
enum IncomeConfidence { low, medium, high }

extension IncomeConfidenceLabel on IncomeConfidence {
  String get label => switch (this) {
        IncomeConfidence.low => 'Low',
        IncomeConfidence.medium => 'Medium',
        IncomeConfidence.high => 'High',
      };
}

/// Money the user expects to receive, kept separate from confirmed income.
///
/// An expected amount is never part of the balance, the allowance or the
/// income statistics until [received] is true and an actual transaction has
/// been recorded.
class ExpectedIncome {
  const ExpectedIncome({
    required this.id,
    required this.title,
    required this.amount,
    required this.expectedDate,
    this.confidence = IncomeConfidence.medium,
    this.received = false,
    this.receivedDate,
    this.categoryId = 'other-income',
    this.note = '',
  });

  final String id;
  final String title;
  final double amount;
  final DateTime expectedDate;
  final IncomeConfidence confidence;
  final bool received;
  final DateTime? receivedDate;
  final String categoryId;
  final String note;

  bool isOverdue(DateTime now) {
    if (received) return false;
    final today = DateTime(now.year, now.month, now.day);
    final due =
        DateTime(expectedDate.year, expectedDate.month, expectedDate.day);
    return due.isBefore(today);
  }

  int daysLate(DateTime now) {
    if (received) return 0;
    final today = DateTime(now.year, now.month, now.day);
    final due =
        DateTime(expectedDate.year, expectedDate.month, expectedDate.day);
    final diff = today.difference(due).inDays;
    return diff > 0 ? diff : 0;
  }

  ExpectedIncome copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? expectedDate,
    IncomeConfidence? confidence,
    bool? received,
    DateTime? receivedDate,
    String? categoryId,
    String? note,
  }) {
    return ExpectedIncome(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      expectedDate: expectedDate ?? this.expectedDate,
      confidence: confidence ?? this.confidence,
      received: received ?? this.received,
      receivedDate: receivedDate ?? this.receivedDate,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
    );
  }

  factory ExpectedIncome.fromJson(Map<String, dynamic> json) {
    return ExpectedIncome(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      expectedDate: DateTime.tryParse(json['expectedDate']?.toString() ?? '') ??
          DateTime.now(),
      confidence: IncomeConfidence.values.firstWhere(
        (c) => c.name == json['confidence'],
        orElse: () => IncomeConfidence.medium,
      ),
      received: json['received'] == true,
      receivedDate: DateTime.tryParse(json['receivedDate']?.toString() ?? ''),
      categoryId: (json['categoryId'] ?? 'other-income').toString(),
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
        'expectedDate': expectedDate.toIso8601String(),
        'confidence': confidence.name,
        'received': received,
        'receivedDate': receivedDate?.toIso8601String(),
        'categoryId': categoryId,
        'note': note,
      };

  @override
  bool operator ==(Object other) => other is ExpectedIncome && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
