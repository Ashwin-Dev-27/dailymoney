import 'package:flutter_test/flutter_test.dart';

import 'package:dailymoney/services/demo_seed.dart';
import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/utils/format.dart';

void main() {
  group('format utils', () {
    test('fmtMoney adds symbol and thousands separator', () {
      expect(fmtMoney(1234.5, 'USD'), r'$1,234.50');
      expect(fmtMoney(0, 'EUR'), '€0.00');
      expect(fmtMoney(1000000, 'JPY'), '¥1,000,000');
    });

    test('fmtSigned marks direction', () {
      expect(
        fmtSigned(25.5, 'USD', isExpense: true),
        '-\$25.50',
      );
      expect(fmtSigned(7, 'USD', isExpense: false), '+\$7.00');
    });

    test('dayLabel knows today and yesterday', () {
      final now = DateTime.now();
      expect(dayLabel(now), 'Today');
      expect(dayLabel(now.subtract(const Duration(days: 1))), 'Yesterday');
      expect(dayLabel(DateTime(2026, 3, 9)), '9 Mar 2026');
    });

    test('monthAdd walks across year boundaries', () {
      expect(monthAdd(DateTime(2026, 1), -1), DateTime(2025, 12));
      expect(monthAdd(DateTime(2026, 11), 2), DateTime(2027, 1));
    });

    test('monthOf trims to first day', () {
      final m = monthOf(DateTime(2026, 5, 19, 14, 3));
      expect(m, DateTime(2026, 5));
    });

    test('parseAmount accepts grouped and decimal-comma input', () {
      expect(parseAmount('1234.50'), 1234.5);
      expect(parseAmount('1,234.50'), 1234.5);
      expect(parseAmount('1,200'), 1200);
      expect(parseAmount('12,50'), 12.5);
      expect(parseAmount('1.234,56'), 1234.56);
      expect(parseAmount('1,23,456'), 123456);
      expect(parseAmount('1.234.567'), 1234567);
      expect(parseAmount(' 42 '), 42);
      expect(parseAmount('1.2.3'), isNull);
      expect(parseAmount(''), isNull);
    });

    test('fmtMonthLeft avoids negative "left" wording', () {
      expect(fmtMonthLeft(120, 'USD'), r'$120.00 left this month');
      expect(fmtMonthLeft(0, 'USD'), r'$0.00 left this month');
      expect(fmtMonthLeft(-20.5, 'USD'), r'$20.50 over this month');
    });
  });

  group('DemoSeed', () {
    final seeds = DemoSeed().generate();

    test('generates a healthy amount of transactions', () {
      expect(seeds.length, greaterThan(40));
      expect(seeds.length, lessThan(120));
    });

    test('no future dates', () {
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        23,
        59,
      );
      for (final t in seeds) {
        expect(t.date.isBefore(today), isTrue, reason: '${t.date} is future');
      }
    });

    test('amounts are positive with cent precision', () {
      for (final t in seeds) {
        expect(t.amount, greaterThan(0));
        expect(t.amount * 100, (t.amount * 100).roundToDouble());
      }
    });

    test('covers both income and expense types', () {
      expect(seeds.any((t) => t.type == TxType.income), isTrue);
      expect(seeds.any((t) => t.type == TxType.expense), isTrue);
    });

    test('ids are unique', () {
      expect(seeds.map((t) => t.id).toSet().length, seeds.length);
    });
  });
}
