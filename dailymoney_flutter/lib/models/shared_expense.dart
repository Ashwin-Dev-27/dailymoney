import 'dart:math' as math;

/// Which way money is owed.
enum SharedDirection {
  /// The user paid, and other people owe the user.
  owedToMe,

  /// Someone else paid, and the user owes them.
  iOwe,
}

extension SharedDirectionLabel on SharedDirection {
  String get label => this == SharedDirection.owedToMe ? 'Owed to me' : 'I owe';

  String get shortLabel =>
      this == SharedDirection.owedToMe ? 'Receivable' : 'Payable';
}

/// A payment shared with friends, roommates or family.
///
/// Only the user's own share counts as spending (through the linked [Tx]).
/// Money owed is never treated as income until a settlement is recorded.
class SharedExpense {
  const SharedExpense({
    required this.id,
    required this.title,
    required this.total,
    required this.myShare,
    required this.direction,
    required this.date,
    this.settled = 0,
    this.categoryId = 'other',
    this.linkedTxId,
    this.counterparty = '',
    this.note = '',
  });

  final String id;
  final String title;

  /// What was paid in total.
  final double total;

  /// The user's own part of [total].
  final double myShare;
  final SharedDirection direction;
  final DateTime date;

  /// How much of the other side's part has been settled.
  final double settled;
  final String categoryId;

  /// The expense entry that recorded the user's payment, when there is one.
  final String? linkedTxId;
  final String counterparty;
  final String note;

  double get owed => direction == SharedDirection.owedToMe
      ? math.max(0.0, total - myShare)
      : math.max(0.0, myShare);

  double get outstanding => math.max(0.0, owed - settled);

  bool get isSettled => outstanding <= 0.005;

  double get progress => owed <= 0 ? 1 : (settled / owed).clamp(0.0, 1.0);

  SharedExpense copyWith({
    String? id,
    String? title,
    double? total,
    double? myShare,
    SharedDirection? direction,
    DateTime? date,
    double? settled,
    String? categoryId,
    String? linkedTxId,
    String? counterparty,
    String? note,
  }) {
    return SharedExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      total: total ?? this.total,
      myShare: myShare ?? this.myShare,
      direction: direction ?? this.direction,
      date: date ?? this.date,
      settled: settled ?? this.settled,
      categoryId: categoryId ?? this.categoryId,
      linkedTxId: linkedTxId ?? this.linkedTxId,
      counterparty: counterparty ?? this.counterparty,
      note: note ?? this.note,
    );
  }

  factory SharedExpense.fromJson(Map<String, dynamic> json) {
    final total = _toDouble(json['total']);
    final share = _toDouble(json['myShare']);
    return SharedExpense(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      total: total,
      myShare: share.clamp(0.0, total <= 0 ? share : total).toDouble(),
      direction: json['direction'] == 'iOwe'
          ? SharedDirection.iOwe
          : SharedDirection.owedToMe,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      settled: math.max(0.0, _toDouble(json['settled'])),
      categoryId: (json['categoryId'] ?? 'other').toString(),
      linkedTxId: json['linkedTxId']?.toString(),
      counterparty: (json['counterparty'] ?? '').toString(),
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
        'total': total,
        'myShare': myShare,
        'direction': direction.name,
        'date': date.toIso8601String(),
        'settled': settled,
        'categoryId': categoryId,
        'linkedTxId': linkedTxId,
        'counterparty': counterparty,
        'note': note,
      };

  @override
  bool operator ==(Object other) => other is SharedExpense && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
