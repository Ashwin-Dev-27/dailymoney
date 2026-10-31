import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/expected_income.dart';
import 'package:dailymoney/models/savings_goal.dart';
import 'package:dailymoney/models/shared_expense.dart';
import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/models/upcoming_expense.dart';
import 'package:dailymoney/providers/expected_income_provider.dart';
import 'package:dailymoney/providers/goals_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/shared_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/providers/upcoming_provider.dart';
import 'package:dailymoney/services/backup_service.dart';
import 'package:dailymoney/services/storage_service.dart';

/// Fails the first financial write and succeeds afterwards, so the rollback
/// path can be exercised without a real storage fault.
class _FailOnceStorage extends StorageService {
  bool _failed = false;

  @override
  Future<void> replaceFinancialData({
    required List<Tx> transactions,
    required List<UpcomingExpense> upcoming,
    required List<SavingsGoal> goals,
    required List<ExpectedIncome> expectedIncome,
    required List<SharedExpense> sharedExpenses,
  }) async {
    if (!_failed) {
      _failed = true;
      throw StateError('simulated write failure');
    }
    return super.replaceFinancialData(
      transactions: transactions,
      upcoming: upcoming,
      goals: goals,
      expectedIncome: expectedIncome,
      sharedExpenses: sharedExpenses,
    );
  }
}

Future<StorageService> emptyStorage() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return storage;
}

Map<String, dynamic> backup({
  List<Map<String, dynamic>> transactions = const [],
  List<Map<String, dynamic>> upcoming = const [],
  List<Map<String, dynamic>> goals = const [],
  List<Map<String, dynamic>> expectedIncome = const [],
  List<Map<String, dynamic>> sharedExpenses = const [],
  Map<String, dynamic> settings = const {},
}) =>
    {
      'app': 'DailyMoney',
      'version': 1,
      'exportedAt': '2026-10-30T10:00:00.000',
      'transactions': transactions,
      'upcoming': upcoming,
      'goals': goals,
      'expectedIncome': expectedIncome,
      'sharedExpenses': sharedExpenses,
      'settings': settings,
    };

Map<String, dynamic> oneOfEverything() => backup(
      transactions: [
        Tx(
          id: 't1',
          title: 'Coffee',
          amount: 4.5,
          type: TxType.expense,
          categoryId: 'food',
          date: DateTime(2026, 10, 1, 9),
          note: 'morning',
        ).toJson(),
      ],
      upcoming: [
        UpcomingExpense(
          id: 'u1',
          title: 'Rent',
          amount: 900,
          categoryId: 'bills',
          dueDate: DateTime(2026, 11, 1),
          repeatMonthly: true,
        ).toJson(),
      ],
      goals: [
        SavingsGoal(
          id: 'g1',
          title: 'Laptop',
          target: 1200,
          saved: 300,
          targetDate: DateTime(2027, 1, 1),
        ).toJson(),
      ],
      expectedIncome: [
        ExpectedIncome(
          id: 'e1',
          title: 'Salary',
          amount: 2500,
          expectedDate: DateTime(2026, 11, 5),
        ).toJson(),
      ],
      sharedExpenses: [
        SharedExpense(
          id: 's1',
          title: 'Dinner',
          total: 90,
          myShare: 30,
          direction: SharedDirection.owedToMe,
          date: DateTime(2026, 10, 2),
        ).toJson(),
      ],
      settings: const {
        'currencyCode': 'INR',
        'userName': 'Asha',
        'monthlyBudget': 5000,
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a complete backup parses every record type', () {
    final document = parseBackup(jsonEncode(oneOfEverything()));

    expect(document.transactions.single.title, 'Coffee');
    expect(document.transactions.single.amount, 4.5);
    expect(document.upcoming.single.title, 'Rent');
    expect(document.goals.single.title, 'Laptop');
    expect(document.expectedIncome.single.title, 'Salary');
    expect(document.sharedExpenses.single.title, 'Dinner');
    expect(document.settings['currencyCode'], 'INR');
    expect(document.totalRecords, 5);
  });

  test('invalid backups are rejected with a readable reason', () {
    final cases = <String, String Function(Map<String, dynamic>)>{
      'empty text': (_) => '   ',
      'not JSON': (_) => '{not json',
      'not DailyMoney': (data) => jsonEncode({...data, 'app': 'Other'}),
      'unknown version': (data) => jsonEncode({...data, 'version': 99}),
      'missing transactions': (data) {
        data.remove('transactions');
        return jsonEncode(data);
      },
      'duplicate ids': (data) {
        final tx = (data['transactions'] as List).first as Map;
        data['transactions'] = [
          tx,
          {...tx}
        ];
        return jsonEncode(data);
      },
      'negative amount': (data) {
        data['transactions'] = [
          {
            'id': 't1',
            'title': 'Bad',
            'amount': -1,
            'type': 'expense',
            'categoryId': 'other',
            'date': '2026-10-01T00:00:00.000',
          },
        ];
        return jsonEncode(data);
      },
      'invalid date': (data) {
        data['transactions'] = [
          {
            'id': 't1',
            'title': 'Bad',
            'amount': 1,
            'type': 'expense',
            'categoryId': 'other',
            'date': 'not-a-date',
          },
        ];
        return jsonEncode(data);
      },
    };

    for (final entry in cases.entries) {
      final data = oneOfEverything();
      expect(
        () => parseBackup(entry.value(data)),
        throwsA(isA<BackupFormatException>()),
        reason: entry.key,
      );
    }
  });

  test('restore replaces records but keeps device security and consent',
      () async {
    final storage = await emptyStorage();
    await storage.saveSecurity({
      'pinEnabled': true,
      'autoLockSeconds': 60,
    });
    await storage.saveSettings({
      'currencyCode': 'USD',
      'userName': 'Old name',
      'monthlyBudget': 10,
      'blockScreenshots': false,
      'welcomeSeen': true,
      'legalAcceptedVersion': '2026-01',
    });

    final settings = SettingsProvider(storage);
    await settings.load();
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();
    final goals = GoalsProvider(storage);
    await goals.load();
    final expectedIncome = ExpectedIncomeProvider(storage);
    await expectedIncome.load();
    final shared = SharedProvider(storage);
    await shared.load();

    await transactions.add(
      Tx(
        id: 'old',
        title: 'Old record',
        amount: 10,
        type: TxType.expense,
        categoryId: 'other',
        date: DateTime(2026, 9, 1),
      ),
    );

    final document = parseBackup(jsonEncode(oneOfEverything()));
    final result = await restoreBackup(
      storage: storage,
      settings: settings,
      transactions: transactions,
      upcoming: upcoming,
      goals: goals,
      expectedIncome: expectedIncome,
      shared: shared,
      document: document,
    );

    expect(result.transactions, 1);
    expect(transactions.all.single.title, 'Coffee');
    expect(upcoming.all.single.title, 'Rent');
    expect(goals.all.single.title, 'Laptop');
    expect(expectedIncome.all.single.title, 'Salary');
    expect(shared.all.single.title, 'Dinner');

    expect(settings.currencyCode, 'INR');
    expect(settings.userName, 'Asha');
    expect(settings.monthlyBudget, 5000);

    // The backup cannot change device security, screenshot blocking, consent or
    // onboarding. Those remain exactly as they were before the restore.
    final security = await storage.loadSecurity();
    expect(security['pinEnabled'], isTrue);
    expect(security['autoLockSeconds'], 60);
    expect(settings.blockScreenshots, isFalse);
    expect(settings.welcomeSeen, isTrue);
    expect(settings.legalAcceptedVersion, '2026-01');
  });

  test('restore with an empty backup clears financial records only', () async {
    final storage = await emptyStorage();
    await storage.saveSecurity({'pinEnabled': true});
    final settings = SettingsProvider(storage);
    await settings.load();
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();
    final goals = GoalsProvider(storage);
    await goals.load();
    final expectedIncome = ExpectedIncomeProvider(storage);
    await expectedIncome.load();
    final shared = SharedProvider(storage);
    await shared.load();

    await transactions.add(
      Tx(
        id: 'old',
        title: 'Old record',
        amount: 10,
        type: TxType.expense,
        categoryId: 'other',
        date: DateTime(2026, 9, 1),
      ),
    );

    await restoreBackup(
      storage: storage,
      settings: settings,
      transactions: transactions,
      upcoming: upcoming,
      goals: goals,
      expectedIncome: expectedIncome,
      shared: shared,
      document: parseBackup(jsonEncode(backup())),
    );

    expect(transactions.isEmpty, isTrue);
    expect((await storage.loadSecurity())['pinEnabled'], isTrue);
  });

  test('unreadable stored data is surfaced and never exported as empty',
      () async {
    SharedPreferences.setMockInitialValues({
      'dm.transactions.v1': '{broken json',
    });
    final storage = StorageService();
    await storage.init();

    expect(await storage.loadTransactions(), isEmpty);
    expect(storage.hasReadFailure, isTrue);
    expect(storage.readFailureKeys, contains('dm.transactions.v1'));
    expect(storage.exportJson(), throwsStateError);

    await storage.clearAll();
    expect(storage.hasReadFailure, isFalse);
    expect(storage.readFailureKeys, isEmpty);
  });

  test(
      'encrypted data without its device key is a read failure, not empty data',
      () async {
    SharedPreferences.setMockInitialValues({
      'dm.transactions.v1': 'enc1:unreadable-without-the-keystore',
    });
    final storage = StorageService();
    await storage.init();

    expect(await storage.loadTransactions(), isEmpty);
    expect(storage.hasReadFailure, isTrue);
    expect(storage.readFailureKeys, contains('dm.transactions.v1'));
  });

  test('screenshot blocking defaults on and survives a reload', () async {
    final storage = await emptyStorage();
    final settings = SettingsProvider(storage);
    await settings.load();

    expect(settings.blockScreenshots, isTrue);
    await settings.setBlockScreenshots(false);

    final reloaded = SettingsProvider(storage);
    await reloaded.load();
    expect(reloaded.blockScreenshots, isFalse);

    await reloaded.resetToDefaults();
    expect(reloaded.blockScreenshots, isTrue);
  });

  test('a failed restore rolls the previous financial records back', () async {
    final storage = _FailOnceStorage();
    await storage.init();
    final settings = SettingsProvider(storage);
    await settings.load();
    final transactions = TransactionsProvider(storage);
    await transactions.load();
    final upcoming = UpcomingProvider(storage);
    await upcoming.load();
    final goals = GoalsProvider(storage);
    await goals.load();
    final expectedIncome = ExpectedIncomeProvider(storage);
    await expectedIncome.load();
    final shared = SharedProvider(storage);
    await shared.load();

    await transactions.add(
      Tx(
        id: 'keep-me',
        title: 'Old record',
        amount: 10,
        type: TxType.expense,
        categoryId: 'other',
        date: DateTime(2026, 9, 1),
      ),
    );

    final document = parseBackup(jsonEncode(oneOfEverything()));
    await expectLater(
      restoreBackup(
        storage: storage,
        settings: settings,
        transactions: transactions,
        upcoming: upcoming,
        goals: goals,
        expectedIncome: expectedIncome,
        shared: shared,
        document: document,
      ),
      throwsA(isA<BackupRestoreException>()),
    );

    expect(transactions.all.single.title, 'Old record');
    expect(upcoming.all, isEmpty);
    expect(goals.all, isEmpty);
    expect(expectedIncome.all, isEmpty);
    expect(shared.all, isEmpty);
    expect(settings.monthlyBudget, 0);
    expect(settings.currencyCode, 'USD');
  });
}
