import 'package:intl/intl.dart';

/// Currency display metadata.
class Currency {
  final String code;
  final String symbol;
  final String name;
  final int decimals;
  const Currency(this.code, this.symbol, this.name, {this.decimals = 2});
}

const List<Currency> kCurrencies = [
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('JPY', '¥', 'Japanese Yen', decimals: 0),
  Currency('CNY', r'CN¥', 'Chinese Yuan'),
  Currency('AUD', r'A$', 'Australian Dollar'),
  Currency('CAD', r'CA$', 'Canadian Dollar'),
];

Currency currencyByCode(String code) => kCurrencies
    .firstWhere((c) => c.code == code, orElse: () => kCurrencies.first);

/// Formats a monetary amount, e.g. "1,234.50".
String fmtMoney(double value, String currencyCode) {
  final c = currencyByCode(currencyCode);
  final pattern = c.decimals == 0 ? '#,##0' : '#,##0.00';
  final n = NumberFormat(pattern, 'en_US');
  return '${c.symbol}${n.format(value)}';
}

/// Formats a signed amount for transaction rows, e.g. "-23.90".
String fmtSigned(double value, String currencyCode, {required bool isExpense}) {
  return '${isExpense ? '-' : '+'}${fmtMoney(value, currencyCode)}';
}

/// "1,234.50 left this month" or "$20.00 over this month".
///
/// Keeps notification and alert copy readable when the month is overspent
/// instead of printing a negative "left" amount.
String fmtMonthLeft(double value, String currencyCode) {
  return value < 0
      ? '${fmtMoney(-value, currencyCode)} over this month'
      : '${fmtMoney(value, currencyCode)} left this month';
}

/// Formats an amount for an editable text field.
///
/// Keeps cents (unlike a rounded display) but drops pointless trailing zeros,
/// so 1234.50 shows as "1234.5" and 1235.00 as "1235".
String fmtAmountInput(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  var text = value.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  return text;
}

/// Parses a user-entered amount.
///
/// Accepts both grouping styles people actually type:
///   "1,234.50" / "1,200" / "12,50" (decimal comma) / "1.234,56".
/// Returns null when the text is not a number.
double? parseAmount(String input) {
  var text = input.trim().replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) return null;

  final lastComma = text.lastIndexOf(',');
  final lastDot = text.lastIndexOf('.');

  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      // European style: 1.234,56 → 1234.56
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // US/Indian style: 1,234.56 → 1234.56
      text = text.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    final parts = text.split(',');
    final last = parts.last;
    if (parts.length == 2 && last.isNotEmpty && last.length <= 2) {
      // Decimal comma: 12,50 → 12.50
      text = '${parts.first}.$last';
    } else {
      // Thousands separators: 1,200 or 1,23,456
      text = text.replaceAll(',', '');
    }
  } else if (lastDot >= 0) {
    final parts = text.split('.');
    if (parts.length > 2 &&
        parts.skip(1).every((p) => p.isNotEmpty && p.length == 3)) {
      // Grouping with dots: 1.234.567 → 1234567
      text = parts.join();
    }
  }

  return double.tryParse(text);
}

/// Compact number for chart axis, e.g. "2.5K".
String fmtCompact(double value) {
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  if (value == 0) return '0';
  return value.round().toString();
}

String twoDigits(int n) => n.toString().padLeft(2, '0');

/// "Today", "Yesterday" or "12 Oct 2026".
String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('d MMM yyyy').format(d);
}

/// "Due today", "2 days overdue" or "Due 12 Nov".
String dueLabel(DateTime due) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  if (diff > 1 && diff <= 7) return 'Due in $diff days';
  if (diff < 0) {
    final n = -diff;
    return '$n ${n == 1 ? 'day' : 'days'} overdue';
  }
  return 'Due ${DateFormat('d MMM').format(day)}';
}

/// "October 2026".
String monthLabel(DateTime month) => DateFormat('MMMM yyyy').format(month);

/// "Oct".
String shortMonthLabel(DateTime month) => DateFormat('MMM').format(month);

/// "14:35 · Tue".
String timeLabel(DateTime d) => DateFormat('HH:mm').format(d);

bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// First day of the month that contains [d].
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// The month exactly one back / forward.
DateTime monthAdd(DateTime month, int delta) {
  // Work in absolute month indices so year boundaries behave.
  final idx = month.year * 12 + month.month - 1 + delta;
  return DateTime(idx ~/ 12, idx % 12 + 1);
}

/// Short weekday header, "Mon".
String weekdayLabel(DateTime d) => DateFormat('EEE').format(d);
