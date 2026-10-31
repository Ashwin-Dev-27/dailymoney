import 'package:flutter_test/flutter_test.dart';
import 'package:dailymoney/models/tx.dart';

void main() {
  group('Tx model', () {
    test('json round trip preserves all fields', () {
      final tx = Tx(
        id: 'abc',
        title: 'Groceries',
        amount: 42.5,
        type: TxType.expense,
        categoryId: 'groceries',
        date: DateTime(2026, 10, 12, 8, 30),
        note: 'weekly run',
      );

      final json = tx.toJson();
      final back = Tx.fromJson(json);

      expect(back.id, tx.id);
      expect(back.title, tx.title);
      expect(back.amount, tx.amount);
      expect(back.type, tx.type);
      expect(back.categoryId, tx.categoryId);
      expect(back.date, tx.date);
      expect(back.note, tx.note);
    });

    test('settlement fields round trip on an income entry', () {
      final tx = Tx(
        id: 'repayment',
        title: 'Received · dinner',
        amount: 600,
        type: TxType.income,
        categoryId: 'other-income',
        date: DateTime(2026, 10, 12),
        isSettlement: true,
        settlementOf: 'shared-1',
      );

      final back = Tx.fromJson(tx.toJson());

      expect(back.isSettlement, isTrue);
      expect(back.settlementOf, 'shared-1');
    });

    test('fromJson drops a settlement flag stored on an expense', () {
      final tx = Tx.fromJson({
        'id': 'old',
        'title': 'Old switched entry',
        'amount': 600,
        'type': 'expense',
        'categoryId': 'other',
        'date': '2026-10-12T00:00:00.000',
        'isSettlement': true,
      });

      expect(tx.type, TxType.expense);
      expect(tx.isSettlement, isFalse);
      expect(tx.statAmount, 600);
    });

    test('a settlement cannot be constructed as an expense', () {
      expect(
        () => Tx(
          id: 'bad',
          title: 'Bad',
          amount: 10,
          type: TxType.expense,
          categoryId: 'other',
          date: DateTime(2026, 10, 12),
          isSettlement: true,
        ),
        throwsAssertionError,
      );
    });

    test('fromJson is tolerant of odd amount types', () {
      final tx = Tx.fromJson({
        'id': 'x1',
        'title': 'Odd',
        'amount': '123.45', // string
        'type': 'income',
        'categoryId': 'salary',
        'date': '2026-01-05T00:00:00.000',
      });
      expect(tx.amount, 123.45);
      expect(tx.type.isIncome, isTrue);
    });

    test('fromJson falls back on missing/broken fields', () {
      final tx = Tx.fromJson({});
      expect(tx.title, '');
      expect(tx.amount, 0);
      expect(tx.type, TxType.expense);
      expect(tx.date, isNotNull);
    });

    test('copyWith overrides only provided fields', () {
      final tx = Tx(
        id: 'a',
        title: 'T',
        amount: 10,
        type: TxType.expense,
        categoryId: 'food',
        date: DateTime(2026, 3, 3),
      );
      final updated = tx.copyWith(amount: 20, type: TxType.income);
      expect(updated.amount, 20);
      expect(updated.type, TxType.income);
      expect(updated.title, 'T');
      expect(updated.categoryId, 'food');
      expect(updated.id, 'a');
    });

    test('equality is id-based', () {
      final a = Tx(
          id: 'same',
          title: 'A',
          amount: 1,
          type: TxType.expense,
          categoryId: 'other',
          date: DateTime(2026, 1, 1));
      final b = Tx(
          id: 'same',
          title: 'B',
          amount: 2,
          type: TxType.income,
          categoryId: 'gift',
          date: DateTime(2026, 2, 2));
      expect(a, equals(b));
    });
  });
}
