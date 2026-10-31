import 'package:flutter_test/flutter_test.dart';

import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/services/statement_parser.dart';

/// Bank and UPI CSV exports must import cleanly.
void main() {
  test('parses debit/credit columns and sorts newest first', () {
    const csv = 'Txn Date,Narration,Debit,Credit\n'
        '03/10/2026,UPI/DR/123/Blinkit/order,450.00,\n'
        '04/10/2026,Cashback from bank,,75.25\n';

    final rows = StatementParser.parse(csv);

    expect(rows, hasLength(2));
    // Newest row first.
    expect(rows.first.date, DateTime(2026, 10, 4, 12));
    expect(rows.first.type, TxType.income);
    expect(rows.first.amount, 75.25);
    expect(rows.first.title, 'Cashback from bank');

    expect(rows.last.date, DateTime(2026, 10, 3, 12));
    expect(rows.last.type, TxType.expense);
    expect(rows.last.amount, 450);
    expect(rows.last.title, contains('Blinkit'));
  });

  test('parses semicolon files with a DR/CR type column', () {
    const csv = 'Date;Description;Amount;Type\n'
        '01 Oct 2026;Salary;50000;CR\n'
        '02 Oct 2026;Big Bazaar;1200;DR\n'
        '03 Oct 2026;Refund;199.50;cr\n';

    final rows = StatementParser.parse(csv);

    expect(rows.map((r) => r.type), [
      TxType.income,
      TxType.expense,
      TxType.income,
    ]);
    expect(rows.map((r) => r.amount), [199.5, 1200, 50000]);
  });

  test('parses tab separated exports and quoted amounts with symbols', () {
    const csv = 'Date\tDescription\tAmount\n'
        '2026-10-05\tMetro card top-up\t"₹1,234.50"\n';

    final rows = StatementParser.parse(csv);

    expect(rows, hasLength(1));
    expect(rows.single.amount, 1234.5);
    expect(rows.single.title, 'Metro card top-up');
    expect(rows.single.date, DateTime(2026, 10, 5, 12));
  });

  test('negative amounts become expenses and parentheses are honoured', () {
    const csv = 'Date,Description,Amount\n'
        '2026-10-06,Subscription,-499.00\n'
        '2026-10-07,Correction,(25.50)\n';

    final rows = StatementParser.parse(csv);

    expect(rows, hasLength(2));
    expect(rows.every((r) => r.type == TxType.expense), isTrue);
    expect(rows.map((r) => r.amount), [25.5, 499]);
  });

  test('strips bank narration prefixes and caps long titles', () {
    final longTitle = 'x' * 120;
    final csv = 'Date,Description,Amount\n'
        '2026-10-08,NEFT/Store payment,50\n'
        '2026-10-09,$longTitle,10\n';

    final rows = StatementParser.parse(csv);

    expect(rows.first.title.length, 80);
    expect(rows.last.title, 'Store payment');
  });

  test('skips rows without a date or a usable amount', () {
    const csv = 'Date,Description,Amount\n'
        'not a date,Broken,100\n'
        '2026-10-10,Zero,0\n'
        '2026-10-11,Empty,\n'
        '2026-10-12,Valid,12.25\n';

    final rows = StatementParser.parse(csv);

    expect(rows, hasLength(1));
    expect(rows.single.title, 'Valid');
  });

  test('parses statement-style rows without a header', () {
    const csv = '2026-10-13,Coffee,120\n'
        '2026-10-14,Salary,3000,credit\n';

    final rows = StatementParser.parse(csv);

    expect(rows, hasLength(2));
    expect(rows.first.type, TxType.income);
    expect(rows.first.title, 'Salary');
    expect(rows.last.type, TxType.expense);
  });

  test('returns nothing for empty input', () {
    expect(StatementParser.parse(''), isEmpty);
    expect(StatementParser.parse('   \n  '), isEmpty);
  });

  test('fingerprints are stable for duplicate detection', () {
    const csv = 'Date,Description,Amount\n'
        '2026-10-15,Coffee,120\n';
    final row = StatementParser.parse(csv).single;

    expect(row.fingerprint, '2026-10-15|120.00|coffee');
  });
}
