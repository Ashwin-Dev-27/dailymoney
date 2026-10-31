import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/detection.dart';
import '../models/expected_income.dart';
import '../models/savings_goal.dart';
import '../models/shared_expense.dart';
import '../models/tx.dart';
import '../models/upcoming_expense.dart';
import 'data_vault.dart';
import 'secure_store.dart';

/// Local persistence built on SharedPreferences.
///
/// Every payload is AES-GCM encrypted with a key held in the Android Keystore
/// ([DataVault]). Keys are versioned so future schema changes can migrate
/// safely. When the keystore is unavailable (for example in a widget test) the
/// service transparently falls back to plain JSON.
class StorageService {
  static const String _kTxKey = 'dm.transactions.v1';
  static const String _kSettingsKey = 'dm.settings.v1';
  static const String _kUpcomingKey = 'dm.upcoming.v1';
  static const String _kGoalsKey = 'dm.goals.v1';
  static const String _kDetectionsKey = 'dm.detections.v1';
  static const String _kSecurityKey = 'dm.security.v1';
  static const String _kExpectedIncomeKey = 'dm.expected_income.v1';
  static const String _kSharedExpensesKey = 'dm.shared_expenses.v1';

  /// Plaintext flag + queue shared with the Android notification listener.
  /// Nothing sensitive lives here: only an on/off switch and pending amounts
  /// which are moved into the encrypted store as soon as the app opens.
  static const String _kCaptureFlagKey = 'dm.capture.enabled';
  static const String _kNativeQueueKey = 'dm.capture.queue.v1';
  static const String _kNotifyPromptKey = 'dm.notify.prompt.v1';

  /// Payloads that must be encrypted once a device vault is available.
  static const List<String> _payloadKeys = [
    _kTxKey,
    _kSettingsKey,
    _kUpcomingKey,
    _kGoalsKey,
    _kDetectionsKey,
    _kSecurityKey,
    _kExpectedIncomeKey,
    _kSharedExpensesKey,
  ];

  late SharedPreferences _prefs;
  DataVault? _vault;
  bool _readFailure = false;
  final Set<String> _readFailureKeys = {};

  /// True when a stored payload existed but could not be decrypted or decoded.
  ///
  /// The app must not present this as an empty ledger. `main.dart` shows a
  /// recovery screen instead, so the user can decide whether to erase.
  bool get hasReadFailure => _readFailure;

  /// Keys that failed to load. Intended for diagnostics, not for display.
  List<String> get readFailureKeys => List.unmodifiable(_readFailureKeys);

  void clearReadFailure() {
    _readFailure = false;
    _readFailureKeys.clear();
  }

  Future<void> init({@visibleForTesting DataVault? vaultOverride}) async {
    _prefs = await SharedPreferences.getInstance();
    await SecureStore.init();
    _vault = vaultOverride ?? await DataVault.open();
    await _migrateToVault();
  }

  /// Re-encrypts plaintext payloads written before this version added the
  /// vault, so upgrading in place does not leave old records readable.
  Future<void> _migrateToVault() async {
    final vault = _vault;
    if (vault == null) return;
    for (final key in _payloadKeys) {
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty || vault.isEncrypted(raw)) continue;
      try {
        jsonDecode(raw);
      } catch (_) {
        continue; // Not one of our payloads; never touch it.
      }
      await _prefs.setString(key, await vault.encrypt(raw));
    }
  }

  /// True when new writes are encrypted with a device-bound key.
  bool get encryptionEnabled => _vault != null;

  // ── Transactions ──────────────────────────────────────────

  Future<List<Tx>> loadTransactions() async {
    final decoded = await _readJson(_kTxKey);
    if (decoded is! List) return [];
    try {
      return decoded
          .whereType<Map>()
          .map((e) => Tx.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      _markReadFailure(_kTxKey);
      return [];
    }
  }

  Future<void> saveTransactions(List<Tx> txs) =>
      _writeJson(_kTxKey, txs.map((t) => t.toJson()).toList());

  // ── Upcoming expenses ─────────────────────────────────────

  Future<List<UpcomingExpense>> loadUpcoming() async {
    final decoded = await _readJson(_kUpcomingKey);
    if (decoded is! List) return [];
    try {
      return decoded
          .whereType<Map>()
          .map((e) => UpcomingExpense.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      _markReadFailure(_kUpcomingKey);
      return [];
    }
  }

  Future<void> saveUpcoming(List<UpcomingExpense> items) =>
      _writeJson(_kUpcomingKey, items.map((t) => t.toJson()).toList());

  // ── Savings goals ─────────────────────────────────────────

  Future<List<SavingsGoal>> loadGoals() async {
    final decoded = await _readJson(_kGoalsKey);
    if (decoded is! List) return [];
    try {
      return decoded
          .whereType<Map>()
          .map((e) => SavingsGoal.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      _markReadFailure(_kGoalsKey);
      return [];
    }
  }

  Future<void> saveGoals(List<SavingsGoal> goals) =>
      _writeJson(_kGoalsKey, goals.map((g) => g.toJson()).toList());

  // ── Detected payments (automatic tracking) ────────────────

  Future<List<Detection>> loadDetections() async {
    final decoded = await _readJson(_kDetectionsKey);
    if (decoded is! List) return [];
    try {
      return decoded
          .whereType<Map>()
          .map((e) => Detection.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      _markReadFailure(_kDetectionsKey);
      return [];
    }
  }

  Future<void> saveDetections(List<Detection> items) =>
      _writeJson(_kDetectionsKey, items.map((d) => d.toJson()).toList());

  // ── Expected income (never counted until received) ────────

  Future<List<ExpectedIncome>> loadExpectedIncome() async {
    final decoded = await _readJson(_kExpectedIncomeKey);
    if (decoded is! List) return [];
    try {
      return decoded
          .whereType<Map>()
          .map((e) => ExpectedIncome.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      _markReadFailure(_kExpectedIncomeKey);
      return [];
    }
  }

  Future<void> saveExpectedIncome(List<ExpectedIncome> items) =>
      _writeJson(_kExpectedIncomeKey, items.map((e) => e.toJson()).toList());

  // ── Shared expenses ───────────────────────────────────────

  Future<List<SharedExpense>> loadSharedExpenses() async {
    final decoded = await _readJson(_kSharedExpensesKey);
    if (decoded is! List) return [];
    try {
      return decoded
          .whereType<Map>()
          .map((e) => SharedExpense.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      _markReadFailure(_kSharedExpensesKey);
      return [];
    }
  }

  Future<void> saveSharedExpenses(List<SharedExpense> items) =>
      _writeJson(_kSharedExpensesKey, items.map((e) => e.toJson()).toList());

  /// Reads and clears the queue written by the native listener.
  Future<List<Detection>> takeNativeDetections() async {
    // The listener writes from Android code; refresh the Dart-side cache first.
    try {
      await _prefs.reload();
    } catch (_) {
      // Older plugin versions may not expose reload.
    }
    final raw = _prefs.getString(_kNativeQueueKey);
    if (raw == null || raw.isEmpty) return [];
    await _prefs.remove(_kNativeQueueKey);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Detection.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Mirrors the automatic-tracking switch for the native listener, which
  /// cannot read the encrypted settings payload.
  Future<void> setCaptureEnabled(bool enabled) =>
      _prefs.setBool(_kCaptureFlagKey, enabled);

  /// Read by the native notification listener before it posts a review prompt.
  /// The listener cannot read the encrypted settings payload, so the current
  /// notification consent is mirrored to a plain boolean.
  Future<void> setNotificationPromptsEnabled(bool enabled) =>
      _prefs.setBool(_kNotifyPromptKey, enabled);

  // ── Settings (flattened JSON bag) ─────────────────────────

  Future<Map<String, dynamic>> loadSettings() async =>
      await _loadMap(_kSettingsKey);

  Future<void> saveSettings(Map<String, dynamic> settings) =>
      _writeJson(_kSettingsKey, settings);

  // ── Security flags (PIN hash lives in the keystore) ───────

  Future<Map<String, dynamic>> loadSecurity() async =>
      await _loadMap(_kSecurityKey);

  Future<void> saveSecurity(Map<String, dynamic> security) =>
      _writeJson(_kSecurityKey, security);

  // ── Maintenance ───────────────────────────────────────────

  /// Replaces only the financial payloads used by a backup restore.
  ///
  /// Security state, consent, notification choices and onboarding progress are
  /// intentionally left untouched. The caller reloads the providers afterwards.
  Future<void> replaceFinancialData({
    required List<Tx> transactions,
    required List<UpcomingExpense> upcoming,
    required List<SavingsGoal> goals,
    required List<ExpectedIncome> expectedIncome,
    required List<SharedExpense> sharedExpenses,
  }) async {
    await _writeJson(_kTxKey, transactions.map((t) => t.toJson()).toList());
    await _writeJson(_kUpcomingKey, upcoming.map((t) => t.toJson()).toList());
    await _writeJson(_kGoalsKey, goals.map((g) => g.toJson()).toList());
    await _writeJson(
      _kExpectedIncomeKey,
      expectedIncome.map((e) => e.toJson()).toList(),
    );
    await _writeJson(
      _kSharedExpensesKey,
      sharedExpenses.map((e) => e.toJson()).toList(),
    );
  }

  /// Full JSON backup of everything a user would want to keep.
  Future<String> exportJson() async {
    if (hasReadFailure) {
      throw StateError('Refusing to export unreadable data as an empty backup');
    }
    final data = <String, dynamic>{
      'app': 'DailyMoney',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': await _readJson(_kTxKey) ?? const [],
      'upcoming': await _readJson(_kUpcomingKey) ?? const [],
      'goals': await _readJson(_kGoalsKey) ?? const [],
      'expectedIncome': await _readJson(_kExpectedIncomeKey) ?? const [],
      'sharedExpenses': await _readJson(_kSharedExpensesKey) ?? const [],
      'settings': await _readJson(_kSettingsKey) ?? const {},
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Removes every financial record and preference. Used by "delete all data".
  Future<void> clearAll() async {
    for (final key in [
      _kTxKey,
      _kSettingsKey,
      _kUpcomingKey,
      _kGoalsKey,
      _kDetectionsKey,
      _kSecurityKey,
      _kExpectedIncomeKey,
      _kSharedExpensesKey,
      _kNativeQueueKey,
    ]) {
      await _prefs.remove(key);
    }
    await _prefs.remove(_kCaptureFlagKey);
    await _prefs.remove(_kNotifyPromptKey);
    clearReadFailure();
  }

  // ── Internals ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _loadMap(String key) async {
    final decoded = await _readJson(key);
    if (decoded is Map) {
      try {
        return decoded.cast<String, dynamic>();
      } catch (_) {
        _markReadFailure(key);
        return {};
      }
    }
    if (decoded != null) _markReadFailure(key);
    return {};
  }

  Future<Object?> _readJson(String key) async {
    var raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final vault = _vault;
      if (vault != null && vault.isEncrypted(raw)) {
        raw = await vault.decrypt(raw);
      } else if (vault == null && raw.startsWith('enc1:')) {
        // Encrypted data exists but the device key is unavailable. Treating
        // this as "no data" would look like a wiped ledger.
        _markReadFailure(key);
        return null;
      }
      return jsonDecode(raw);
    } catch (_) {
      // Corrupt or unreadable data must be surfaced, not silently swallowed.
      _markReadFailure(key);
      return null;
    }
  }

  void _markReadFailure(String key) {
    _readFailure = true;
    _readFailureKeys.add(key);
  }

  Future<void> _writeJson(String key, Object value) async {
    var raw = jsonEncode(value);
    final vault = _vault;
    if (vault != null) raw = await vault.encrypt(raw);
    await _prefs.setString(key, raw);
  }
}
