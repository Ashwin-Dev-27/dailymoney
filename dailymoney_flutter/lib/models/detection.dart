import '../models/category.dart';
import '../models/tx.dart';

/// A payment detected in another app's notification, waiting for review.
///
/// Nothing is written to the ledger until the user accepts it, which keeps
/// automatic tracking honest even when a notification is misread.
class Detection {
  final String id;
  final String packageName;
  final String appLabel;
  final String title;
  final String text;
  final double amount;
  final TxType type;
  final DateTime capturedAt;

  const Detection({
    required this.id,
    required this.packageName,
    required this.appLabel,
    required this.title,
    required this.text,
    required this.amount,
    required this.type,
    required this.capturedAt,
  });

  /// Best-effort category from the app and notification wording.
  String get categoryId =>
      categoryIdForText('$appLabel $title $text', income: type.isIncome);

  /// Reasonable title for the ledger entry.
  String get ledgerTitle {
    final t = title.trim();
    if (t.isNotEmpty && t.length <= 48) return t;
    return appLabel;
  }

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      id: (json['id'] ?? '').toString(),
      packageName: (json['packageName'] ?? '').toString(),
      appLabel: (json['appLabel'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      type: (json['type'] ?? '').toString() == 'income'
          ? TxType.income
          : TxType.expense,
      // The native listener stores an ISO-8601 UTC instant; show it in the
      // user's timezone instead of the raw UTC clock.
      capturedAt: _parseLocal(json['capturedAt']),
    );
  }

  static DateTime _parseLocal(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return DateTime.now();
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'packageName': packageName,
        'appLabel': appLabel,
        'title': title,
        'text': text,
        'amount': amount,
        'type': type.name,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
      };
}
