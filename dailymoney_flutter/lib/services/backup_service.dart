import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/expected_income.dart';
import '../models/savings_goal.dart';
import '../models/shared_expense.dart';
import '../models/tx.dart';
import '../models/upcoming_expense.dart';
import '../providers/expected_income_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import 'storage_service.dart';

/// A parsed and validated DailyMoney JSON backup.
///
/// Parsing never writes anything. The caller can show the counts and ask for
/// confirmation before [restoreBackup] replaces current records.
class BackupDocument {
  const BackupDocument({
    required this.transactions,
    required this.upcoming,
    required this.goals,
    required this.expectedIncome,
    required this.sharedExpenses,
    required this.settings,
  });

  final List<Tx> transactions;
  final List<UpcomingExpense> upcoming;
  final List<SavingsGoal> goals;
  final List<ExpectedIncome> expectedIncome;
  final List<SharedExpense> sharedExpenses;
  final Map<String, dynamic> settings;

  int get totalRecords =>
      transactions.length +
      upcoming.length +
      goals.length +
      expectedIncome.length +
      sharedExpenses.length;
}

class BackupImportResult {
  const BackupImportResult({
    required this.transactions,
    required this.upcoming,
    required this.goals,
    required this.expectedIncome,
    required this.sharedExpenses,
  });

  final int transactions;
  final int upcoming;
  final int goals;
  final int expectedIncome;
  final int sharedExpenses;
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when a validated backup could not be applied.
///
/// The message says whether the previous records were put back, because a
/// failed restore must not pretend that nothing changed.
class BackupRestoreException implements Exception {
  const BackupRestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

const int _maxBackupCharacters = 20 * 1024 * 1024;
const int _maxBackupRecords = 100000;

/// Copies the JSON backup to the clipboard and reports the real result.
///
/// Kept in one place so the Privacy screen, Data controls and any future
/// entry point cannot drift into different success messages.
Future<bool> copyBackupToClipboard(BuildContext context) async {
  final storage = context.read<StorageService>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final json = await storage.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Backup copied to clipboard '
          '(${(json.length / 1024).toStringAsFixed(1)} KB). Store it somewhere '
          'safe.',
        ),
      ),
    );
    return true;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not create the backup. Your existing records were not changed.',
        ),
      ),
    );
    return false;
  }
}

/// Parses a backup without touching the database.
///
/// The app's own export is intentionally strict: a malformed backup must not
/// silently overwrite a real ledger with empty or partially parsed records.
BackupDocument parseBackup(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    throw const BackupFormatException('The backup text is empty.');
  }
  if (text.length > _maxBackupCharacters) {
    throw const BackupFormatException(
      'This backup is too large for DailyMoney to read safely.',
    );
  }

  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    throw const BackupFormatException(
      'This is not valid JSON. Copy the complete backup again.',
    );
  }
  final root = _asMap(decoded, 'backup');
  if (root['app'] != 'DailyMoney') {
    throw const BackupFormatException(
      'This JSON file was not exported by DailyMoney.',
    );
  }
  final version = root['version'];
  if (version is! num || version.toInt() != 1) {
    throw const BackupFormatException(
      'This backup uses a format DailyMoney does not understand.',
    );
  }

  final transactions = _parseList(
    root['transactions'],
    'transactions',
    Tx.fromJson,
    _validateTx,
  );
  final upcoming = _parseList(
    root['upcoming'],
    'upcoming bills',
    UpcomingExpense.fromJson,
    _validateUpcoming,
  );
  final goals = _parseList(
    root['goals'],
    'savings goals',
    SavingsGoal.fromJson,
    _validateGoal,
  );
  final expected = _parseList(
    root['expectedIncome'],
    'expected income',
    ExpectedIncome.fromJson,
    _validateExpectedIncome,
  );
  final shared = _parseList(
    root['sharedExpenses'],
    'shared expenses',
    SharedExpense.fromJson,
    _validateSharedExpense,
  );

  final total = transactions.length +
      upcoming.length +
      goals.length +
      expected.length +
      shared.length;
  if (total > _maxBackupRecords) {
    throw const BackupFormatException(
      'This backup contains more records than DailyMoney can restore at once.',
    );
  }

  return BackupDocument(
    transactions: transactions,
    upcoming: upcoming,
    goals: goals,
    expectedIncome: expected,
    sharedExpenses: shared,
    settings: _asMap(root['settings'], 'settings'),
  );
}

/// Replaces financial records with [document] and reloads the providers.
///
/// Security state, consent choices, notification settings and onboarding state
/// are deliberately not imported. Those choices belong to the person using
/// this device, not to an old backup file.
///
/// A failure while writing is rolled back to the records and preferences that
/// were on the device before the restore. If the rollback itself fails, the
/// exception says so instead of claiming that nothing changed.
Future<BackupImportResult> restoreBackup({
  required StorageService storage,
  required SettingsProvider settings,
  required TransactionsProvider transactions,
  required UpcomingProvider upcoming,
  required GoalsProvider goals,
  required ExpectedIncomeProvider expectedIncome,
  required SharedProvider shared,
  required BackupDocument document,
}) async {
  final oldTransactions = List<Tx>.of(transactions.all);
  final oldUpcoming = List<UpcomingExpense>.of(upcoming.all);
  final oldGoals = List<SavingsGoal>.of(goals.all);
  final oldExpectedIncome = List<ExpectedIncome>.of(expectedIncome.all);
  final oldShared = List<SharedExpense>.of(shared.all);
  final oldPreferences = <String, dynamic>{
    'currencyCode': settings.currencyCode,
    'userName': settings.userName,
    'monthlyBudget': settings.monthlyBudget,
    'budgetHistory': settings.budgetHistory,
    'allowancePolicy': settings.allowancePolicy.name,
    'moneyProtection': settings.moneyProtection,
    'emergencyBuffer': settings.emergencyBuffer,
    'studentMode': settings.studentMode,
    'themeMode': settings.themeMode.name,
  };

  try {
    await storage.replaceFinancialData(
      transactions: document.transactions,
      upcoming: document.upcoming,
      goals: document.goals,
      expectedIncome: document.expectedIncome,
      sharedExpenses: document.sharedExpenses,
    );
    await settings.restoreBackupPreferences(document.settings);
  } catch (_) {
    var rolledBack = false;
    try {
      await storage.replaceFinancialData(
        transactions: oldTransactions,
        upcoming: oldUpcoming,
        goals: oldGoals,
        expectedIncome: oldExpectedIncome,
        sharedExpenses: oldShared,
      );
      await settings.restoreBackupPreferences(oldPreferences);
      rolledBack = true;
    } catch (_) {
      // A persistent storage failure can also defeat the rollback.
    }
    try {
      await _reloadAll(
        transactions: transactions,
        upcoming: upcoming,
        goals: goals,
        expectedIncome: expectedIncome,
        shared: shared,
      );
    } catch (_) {
      // The providers will reload on the next screen or app start.
    }
    throw BackupRestoreException(
      rolledBack
          ? 'The restore did not finish. Your previous records were put back.'
          : 'The restore did not finish. Your records may be partially '
              'changed. Export what is present now before trying again.',
    );
  }

  await _reloadAll(
    transactions: transactions,
    upcoming: upcoming,
    goals: goals,
    expectedIncome: expectedIncome,
    shared: shared,
  );

  return BackupImportResult(
    transactions: document.transactions.length,
    upcoming: document.upcoming.length,
    goals: document.goals.length,
    expectedIncome: document.expectedIncome.length,
    sharedExpenses: document.sharedExpenses.length,
  );
}

Future<void> _reloadAll({
  required TransactionsProvider transactions,
  required UpcomingProvider upcoming,
  required GoalsProvider goals,
  required ExpectedIncomeProvider expectedIncome,
  required SharedProvider shared,
}) async {
  await transactions.load();
  await upcoming.load();
  await goals.load();
  await expectedIncome.load();
  await shared.load();
}

Map<String, dynamic> _asMap(Object? value, String label) {
  if (value is! Map) {
    throw BackupFormatException('The $label section is missing or invalid.');
  }
  try {
    return value.cast<String, dynamic>();
  } catch (_) {
    throw BackupFormatException('The $label section uses invalid keys.');
  }
}

List<T> _parseList<T>(
  Object? raw,
  String label,
  T Function(Map<String, dynamic>) parse,
  void Function(Map<String, dynamic>, int) validate,
) {
  if (raw is! List) {
    throw BackupFormatException('The $label section is missing or invalid.');
  }
  final ids = <String>{};
  final out = <T>[];
  for (var i = 0; i < raw.length; i++) {
    final map = _asMap(raw[i], '$label item ${i + 1}');
    validate(map, i);
    final id = (map['id'] ?? '').toString();
    if (id.isEmpty) {
      throw BackupFormatException('$label item ${i + 1} has no id.');
    }
    if (!ids.add(id)) {
      throw BackupFormatException(
        '$label contains the same id more than once.',
      );
    }
    try {
      out.add(parse(map));
    } catch (_) {
      throw BackupFormatException('$label item ${i + 1} could not be read.');
    }
  }
  return out;
}

void _validateTx(Map<String, dynamic> map, int index) {
  _requireId(map, 'Transaction ${index + 1}');
  _requireAmount(map['amount'], 'Transaction ${index + 1}');
  _requireDate(map['date'], 'Transaction ${index + 1}');
  if (map['type'] != 'income' && map['type'] != 'expense') {
    throw BackupFormatException(
      'Transaction ${index + 1} has an unknown type.',
    );
  }
  if (map['personalShare'] != null) {
    _requireAmount(map['personalShare'], 'Transaction ${index + 1} share');
  }
}

void _validateUpcoming(Map<String, dynamic> map, int index) {
  _requireId(map, 'Bill ${index + 1}');
  _requireAmount(map['amount'], 'Bill ${index + 1}');
  _requireDate(map['dueDate'], 'Bill ${index + 1}');
}

void _validateGoal(Map<String, dynamic> map, int index) {
  _requireId(map, 'Goal ${index + 1}');
  _requireAmount(map['target'], 'Goal ${index + 1} target');
  if (map['saved'] != null) {
    _requireAmount(map['saved'], 'Goal ${index + 1} saved amount');
  }
  if (map['targetDate'] != null) {
    _requireDate(map['targetDate'], 'Goal ${index + 1}');
  }
}

void _validateExpectedIncome(Map<String, dynamic> map, int index) {
  _requireId(map, 'Expected income ${index + 1}');
  _requireAmount(map['amount'], 'Expected income ${index + 1}');
  _requireDate(map['expectedDate'], 'Expected income ${index + 1}');
  if (map['receivedDate'] != null) {
    _requireDate(map['receivedDate'], 'Expected income ${index + 1} received');
  }
}

void _validateSharedExpense(Map<String, dynamic> map, int index) {
  _requireId(map, 'Shared expense ${index + 1}');
  _requireAmount(map['total'], 'Shared expense ${index + 1} total');
  _requireAmount(map['myShare'], 'Shared expense ${index + 1} share');
  _requireDate(map['date'], 'Shared expense ${index + 1}');
  if (map['direction'] != 'owedToMe' && map['direction'] != 'iOwe') {
    throw BackupFormatException(
      'Shared expense ${index + 1} has an unknown direction.',
    );
  }
  if (map['settled'] != null) {
    _requireAmount(map['settled'], 'Shared expense ${index + 1} settled');
  }
}

void _requireId(Map<String, dynamic> map, String label) {
  final id = (map['id'] ?? '').toString();
  if (id.trim().isEmpty) {
    throw BackupFormatException('$label has no id.');
  }
}

double _requireAmount(Object? value, String label) {
  if (value is! num || !value.isFinite || value < 0) {
    throw BackupFormatException('$label is not a valid amount.');
  }
  return value.toDouble();
}

void _requireDate(Object? value, String label) {
  if (value is! String || DateTime.tryParse(value) == null) {
    throw BackupFormatException('$label has an invalid date.');
  }
}
