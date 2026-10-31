import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../models/tx.dart';
import '../utils/format.dart';

/// One transaction read from a bank or UPI statement export.
class StatementRow {
  const StatementRow({
    required this.date,
    required this.title,
    required this.amount,
    required this.type,
  });

  final DateTime date;
  final String title;
  final double amount;
  final TxType type;

  /// Stable key used to skip duplicates already in the ledger.
  String get fingerprint =>
      '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}|'
      '${amount.toStringAsFixed(2)}|${title.toLowerCase()}';
}

/// Parses the CSV exports produced by Indian banks and UPI apps.
///
/// Accepts comma, semicolon or tab separated files, with either an `Amount`
/// column or separate `Debit`/`Credit` columns. Dates may be `dd/MM/yyyy`,
/// `yyyy-MM-dd`, `dd MMM yyyy` and similar.
class StatementParser {
  const StatementParser._();

  static List<StatementRow> parse(String input) {
    final text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.trim().isEmpty) return const [];

    final delimiter = _detectDelimiter(text);
    final rows = CsvToListConverter(
      eol: '\n',
      fieldDelimiter: delimiter,
      shouldParseNumbers: false,
    ).convert(text);

    if (rows.isEmpty) return const [];

    var headerIndex = -1;
    var dateCol = -1;
    var descCol = -1;
    var amountCol = -1;
    var debitCol = -1;
    var creditCol = -1;
    var typeCol = -1;

    for (var r = 0; r < rows.length && r < 8; r++) {
      final cells = rows[r].map((e) => _norm(e)).toList();
      final d = cells.indexWhere(_isDateHeader);
      final a = cells.indexWhere((c) =>
          c == 'amount' || c == 'amt' || c.contains('transaction amount'));
      final dr = cells.indexWhere(
          (c) => c.contains('debit') || c.contains('withdrawal') || c == 'dr');
      final cr = cells.indexWhere(
          (c) => c.contains('credit') || c.contains('deposit') || c == 'cr');
      final desc = cells.indexWhere(_isDescriptionHeader);
      if (d >= 0 && desc >= 0 && (a >= 0 || dr >= 0 || cr >= 0)) {
        headerIndex = r;
        dateCol = d;
        descCol = desc;
        amountCol = a;
        debitCol = dr;
        creditCol = cr;
        typeCol = cells.indexWhere((c) =>
            c == 'type' || c.contains('dr/cr') || c.contains('debit/credit'));
        break;
      }
    }

    final out = <StatementRow>[];
    final start = headerIndex >= 0 ? headerIndex + 1 : 0;
    for (var r = start; r < rows.length; r++) {
      final cells = rows[r];
      if (cells.isEmpty) continue;

      String cell(int index) {
        if (index < 0 || index >= cells.length) return '';
        return cells[index]?.toString().trim() ?? '';
      }

      DateTime? date;
      String title;
      double? amount;
      TxType type = TxType.expense;

      if (headerIndex >= 0) {
        date = _parseDate(cell(dateCol));
        title = _cleanTitle(cell(descCol));
        final debit = _parseMoney(cell(debitCol));
        final credit = _parseMoney(cell(creditCol));
        final plain = _parseMoney(cell(amountCol));
        if (debit != null && debit > 0) {
          amount = debit;
          type = TxType.expense;
        } else if (credit != null && credit > 0) {
          amount = credit;
          type = TxType.income;
        } else if (plain != null && plain != 0) {
          amount = plain.abs();
          type = _typeFrom(
            value: cell(typeCol),
            negative: plain < 0,
          );
        }
      } else {
        if (cells.length < 3) continue;
        date = _parseDate(cell(0));
        title = _cleanTitle(cell(1));
        final raw = _parseMoney(cell(2));
        if (raw != null && raw != 0) {
          amount = raw.abs();
          type = _typeFrom(
            value: cells.length > 3 ? cell(3) : '',
            negative: raw < 0,
          );
        }
      }

      if (date == null || amount == null || amount <= 0) continue;
      if (title.isEmpty) title = 'Imported transaction';
      out.add(StatementRow(
        date: DateTime(date.year, date.month, date.day, 12),
        title: title,
        amount: amount,
        type: type,
      ));
    }

    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static String _detectDelimiter(String text) {
    final firstLine = text
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final tabs = '\t'.allMatches(firstLine).length;
    final semis = ';'.allMatches(firstLine).length;
    final commas = ','.allMatches(firstLine).length;
    if (tabs >= semis && tabs >= commas && tabs > 0) return '\t';
    if (semis > commas) return ';';
    return ',';
  }

  static String _norm(Object? value) =>
      (value?.toString() ?? '').toLowerCase().trim();

  static bool _isDateHeader(String c) =>
      c == 'date' ||
      c.contains('txn date') ||
      c.contains('transaction date') ||
      c.contains('value date') ||
      c.contains('posting date');

  static bool _isDescriptionHeader(String c) =>
      c.contains('description') ||
      c.contains('narration') ||
      c.contains('particulars') ||
      c.contains('details') ||
      c.contains('merchant') ||
      c.contains('remarks') ||
      c == 'title' ||
      c == 'name';

  static TxType _typeFrom({required String value, required bool negative}) {
    final v = value.toLowerCase().trim();
    if (v.contains('credit') ||
        v == 'cr' ||
        v.contains('income') ||
        v.contains('deposit')) {
      return TxType.income;
    }
    if (negative) return TxType.expense;
    return TxType.expense;
  }

  static DateTime? _parseDate(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return null;
    const formats = [
      'dd/MM/yyyy',
      'd/M/yyyy',
      'dd-MM-yyyy',
      'd-M-yyyy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'dd MMM yyyy',
      'd MMM yyyy',
      'dd MMMM yyyy',
      'd MMMM yyyy',
      'MMM d, yyyy',
      'dd/MM/yy',
      'd/M/yy',
      'dd-MM-yy',
    ];
    for (final format in formats) {
      try {
        return DateFormat(format).parseStrict(text);
      } catch (_) {
        // Try the next shape.
      }
    }
    return DateTime.tryParse(text);
  }

  static double? _parseMoney(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    final negative = (text.startsWith('(') && text.endsWith(')')) ||
        text.trimLeft().startsWith('-');
    text = text.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    text = text.replaceAll('-', '');
    if (text.isEmpty) return null;
    final value = parseAmount(text);
    if (value == null) return null;
    return negative ? -value : value;
  }

  static String _cleanTitle(String raw) {
    var title = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Bank narrations are often "UPI/DR/123456/Blinkit/..." — keep it readable.
    title =
        title.replaceAll(RegExp(r'^(UPI|NEFT|IMPS|RTGS|POS|ATM)[/\-\s]+'), '');
    if (title.length > 80) title = title.substring(0, 80).trimRight();
    return title;
  }
}
