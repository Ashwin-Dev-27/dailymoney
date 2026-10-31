import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small wrapper around the platform keystore.
///
/// On a real device values live in encrypted shared preferences backed by the
/// Android Keystore. A write is only reported as successful after it has been
/// read back, so a request that silently did nothing cannot be mistaken for
/// durable storage.
///
/// In widget tests the values are kept in memory for the session. Tests get
/// their own deterministic vault in [DataVault], so they never write plaintext
/// to disk either.
class SecureStore {
  SecureStore._();

  static const FlutterSecureStorage _plugin = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Timeout for keystore calls so a wedged OEM implementation cannot hold up
  /// startup.
  static const Duration _timeout = Duration(seconds: 3);

  static final Map<String, String> _memory = <String, String>{};
  static bool _available = false;
  static bool _initialized = false;

  /// True when running under `flutter test`, where plugin channels are absent
  /// and platform calls can wait forever inside fake-async.
  static bool get isTest =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  /// True when the platform keystore answered a real write and read-back.
  static bool get isAvailable => _available;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (isTest) return;
    await _probe();
  }

  /// Re-runs the availability probe after a startup failure.
  static Future<void> retry() async {
    _initialized = false;
    _available = false;
    await init();
  }

  static Future<void> _probe() async {
    const key = 'dm.probe.v1';
    const value = 'ok';
    try {
      await _plugin.write(key: key, value: value).timeout(_timeout);
      final read = await _plugin.read(key: key).timeout(_timeout);
      _available = read == value;
      await _plugin.delete(key: key).timeout(_timeout);
    } catch (_) {
      _available = false;
    }
  }

  static Future<String?> read(String key) async {
    try {
      return await readStrict(key);
    } catch (_) {
      return null;
    }
  }

  /// Like [read], but surfaces a platform failure to the caller. Used for the
  /// vault key, where treating a failed read as "no key yet" would overwrite an
  /// existing key and orphan the encrypted records.
  static Future<String?> readStrict(String key) async {
    if (_memory.containsKey(key)) return _memory[key];
    if (!_available || isTest) return null;
    final value = await _plugin.read(key: key).timeout(_timeout);
    if (value != null) _memory[key] = value;
    return value;
  }

  /// Writes and verifies [value]. Returns false when the platform did not
  /// persist it, or when no durable keystore is available.
  static Future<bool> write(String key, String value) async {
    _memory[key] = value;
    if (isTest) return true;
    if (!_available) return false;
    try {
      await _plugin.write(key: key, value: value).timeout(_timeout);
      final check = await _plugin.read(key: key).timeout(_timeout);
      if (check != value) {
        _available = false;
        return false;
      }
      return true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  static Future<void> delete(String key) async {
    _memory.remove(key);
    if (isTest || !_available) return;
    try {
      await _plugin.delete(key: key).timeout(_timeout);
    } catch (_) {
      // Nothing else to do.
    }
  }
}
