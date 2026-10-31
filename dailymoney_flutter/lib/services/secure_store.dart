import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small wrapper around the platform keystore.
///
/// On a real device values live in encrypted shared preferences backed by the
/// Android Keystore. In widget tests (or any environment where the plugin is
/// missing) the same values are kept in memory for the session so callers do
/// not have to special-case tests.
class SecureStore {
  SecureStore._();

  static const FlutterSecureStorage _plugin = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Timeout for keystore calls so a wedged OEM implementation cannot hold up
  /// startup. Falling back to memory storage is preferable to a frozen app.
  static const Duration _timeout = Duration(seconds: 3);

  static final Map<String, String> _memory = <String, String>{};
  static bool _available = false;
  static bool _initialized = false;

  /// True when running under `flutter test`, where plugin channels are absent
  /// and platform calls can wait forever inside fake-async.
  static bool get isTest =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  /// True when the platform keystore answered — i.e. secrets survive restarts.
  static bool get isAvailable => _available;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (isTest) return;
    try {
      await _plugin.read(key: 'dm.probe.v1').timeout(_timeout);
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  static Future<String?> read(String key) async {
    if (_memory.containsKey(key)) return _memory[key];
    if (!_available) return null;
    try {
      final value = await _plugin.read(key: key).timeout(_timeout);
      if (value != null) _memory[key] = value;
      return value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    _memory[key] = value;
    if (!_available) return;
    try {
      await _plugin.write(key: key, value: value).timeout(_timeout);
    } catch (_) {
      // Best effort: the in-memory copy still protects the running session.
    }
  }

  static Future<void> delete(String key) async {
    _memory.remove(key);
    if (!_available) return;
    try {
      await _plugin.delete(key: key).timeout(_timeout);
    } catch (_) {
      // Nothing else to do.
    }
  }
}
