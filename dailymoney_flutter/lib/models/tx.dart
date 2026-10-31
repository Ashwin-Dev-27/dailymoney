import 'dart:math' as math;

enum TxType { income, expense }

extension TxTypeLabel on TxType {
  String get label => this == TxType.income ? 'Income' : 'Expense';
  bool get isIncome => this == TxType.income;
  bool get isExpense => this == TxType.expense;
}

/// A single money movement: income or expense.
class Tx {
  final String id;
  final String title;
  final double amount;
  final TxType type;
  final String categoryId;
  final DateTime date;
  final String note;

  /// The part of an expense that is the user's own spending.
  ///
  /// A ₹900 meal split three ways has [amount] 900 (what left the account)
  /// and [personalShare] 300 (what actually counts as spending). The rest is
  /// a receivable tracked by a `SharedExpense`. Null means the whole amount.
  final double? personalShare;

  /// A debt settlement rather than new income or new spending.
  ///
  /// Receiving money back from a friend decreases a receivable and increases
  /// the account balance, but it is not income. Settlement movements therefore
  /// affect the balance and never the income/expense statistics.
  final bool isSettlement;

  /// The shared record this entry settles, when it came from one.
  ///
  /// Editing or deleting the settlement keeps the shared record's `settled`
  /// total in step instead of leaving the receivable history inconsistent.
  final String? settlementOf;

  const Tx({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.date,
    this.note = '',
    this.personalShare,
    this.isSettlement = false,
    this.settlementOf,
  }) : assert(
          !isSettlement || type == TxType.income,
          'A settlement is a receipt, so it must be income',
        );

  /// The amount that belongs in spending statistics.
  double get statAmount {
    if (isSettlement) return 0;
    if (type == TxType.income) return amount;
    return personalExpense;
  }

  /// The user's own part of an expense, clamped to a sane range.
  double get personalExpense {
    final share = personalShare;
    if (share == null) return amount;
    return share.clamp(0.0, amount).toDouble();
  }

  /// The part of an expense someone else owes the user.
  double get sharedPortion => math.max(0.0, amount - personalExpense);

  /// How this entry changes the confirmed balance.
  double get balanceDelta => type.isIncome ? amount : -amount;

  /// True when this expense is split with other people.
  bool get isSharedExpense =>
      type == TxType.expense && !isSettlement && sharedPortion > 0.005;

  Tx copyWith({
    String? id,
    String? title,
    double? amount,
    TxType? type,
    String? categoryId,
    DateTime? date,
    String? note,
    double? personalShare,
    bool clearPersonalShare = false,
    bool? isSettlement,
    String? settlementOf,
  }) {
    return Tx(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      personalShare:
          clearPersonalShare ? null : (personalShare ?? this.personalShare),
      isSettlement: isSettlement ?? this.isSettlement,
      settlementOf: settlementOf ?? this.settlementOf,
    );
  }

  factory Tx.fromJson(Map<String, dynamic> json) {
    // Tolerant: persists id/title/amount across type/parse surprises.
    final parsedType =
        json['type'] == 'income' ? TxType.income : TxType.expense;
    final amount = _toDouble(json['amount']);
    final rawShare = json['personalShare'];
    final share = rawShare == null ? null : _toDouble(rawShare);
    return Tx(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      amount: amount,
      type: parsedType,
      categoryId: (json['categoryId'] ?? 'other').toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      note: (json['note'] ?? '').toString(),
      // Older records have no share and behave exactly as before. A share on
      // an income entry is meaningless, so it is discarded.
      personalShare: parsedType == TxType.expense && share != null
          ? share.clamp(0.0, amount).toDouble()
          : null,
      // A settlement is a receipt. Old records saved while switching the type
      // could carry the flag on an expense; that combination must not hide a
      // real expense from the statistics.
      isSettlement: parsedType == TxType.income && json['isSettlement'] == true,
      settlementOf: json['settlementOf']?.toString(),
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
        'type': type == TxType.income ? 'income' : 'expense',
        'categoryId': categoryId,
        'date': date.toIso8601String(),
        'note': note,
        if (personalShare != null) 'personalShare': personalShare,
        if (isSettlement) 'isSettlement': true,
        if (settlementOf != null) 'settlementOf': settlementOf,
      };

  @override
  bool operator ==(Object other) => other is Tx && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
