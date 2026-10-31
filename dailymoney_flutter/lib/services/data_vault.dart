import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'secure_store.dart';

/// Authenticated encryption for everything DailyMoney writes to disk.
///
/// A random 256-bit key is generated on first run and kept in the Android
/// Keystore via [SecureStore]. Values are AES-GCM encrypted, so a copied
/// preferences file cannot be read without that key.
///
/// Storage fails closed: when no durable key is available [open] returns null
/// and [StorageService] refuses to write rather than silently storing plain
/// JSON.
class DataVault {
  DataVault._(this._key);

  static const String _keyName = 'dm.vault.key.v1';
  static const String _prefix = 'enc1:';
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  static final AesGcm _algorithm = AesGcm.with256bits();

  final SecretKey _key;

  /// Builds a vault from known key bytes. Only used by tests; production code
  /// goes through [open] so the key stays in the Keystore.
  @visibleForTesting
  factory DataVault.fromKeyBytes(List<int> bytes) =>
      DataVault._(SecretKey(bytes));

  /// Deterministic in-memory vault for widget and unit tests.
  static DataVault testVault() => DataVault._(
        SecretKey(List<int>.generate(32, (i) => (i * 17 + 29) & 0xff)),
      );

  /// Opens (or creates) the vault.
  ///
  /// Returns null when no durable key material is available. Callers must then
  /// block writes instead of falling back to plain JSON.
  static Future<DataVault?> open() async {
    if (!SecureStore.isAvailable) return null;
    try {
      final stored = await SecureStore.readStrict(_keyName);
      if (stored != null) {
        final bytes = base64Decode(stored);
        // A malformed key must not be replaced: doing so would make every
        // existing encrypted payload unreadable.
        if (bytes.length != 32) return null;
        return DataVault._(SecretKey(bytes));
      }

      final key = await _algorithm.newSecretKey();
      final bytes = await key.extractBytes();
      final persisted = await SecureStore.write(_keyName, base64Encode(bytes));
      if (!persisted) return null;
      return DataVault._(SecretKey(bytes));
    } catch (_) {
      return null;
    }
  }

  bool isEncrypted(String raw) => raw.startsWith(_prefix);

  Future<String> encrypt(String plain) async {
    final box = await _algorithm.encrypt(
      utf8.encode(plain),
      secretKey: _key,
    );
    final bytes = <int>[
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ];
    return '$_prefix${base64Encode(bytes)}';
  }

  Future<String> decrypt(String stored) async {
    final bytes = base64Decode(stored.substring(_prefix.length));
    if (bytes.length < _nonceLength + _macLength) {
      throw const FormatException('Encrypted value is too short');
    }
    final nonce = bytes.sublist(0, _nonceLength);
    final mac = bytes.sublist(bytes.length - _macLength);
    final cipherText = bytes.sublist(_nonceLength, bytes.length - _macLength);
    final clear = await _algorithm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: _key,
    );
    return utf8.decode(clear);
  }
}
