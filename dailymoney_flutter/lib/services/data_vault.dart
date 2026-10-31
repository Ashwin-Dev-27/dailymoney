import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'secure_store.dart';

/// Authenticated encryption for everything DailyMoney writes to disk.
///
/// A random 256-bit key is generated on first run and kept in the Android
/// Keystore via [SecureStore]. Values are AES-GCM encrypted, so a copied
/// preferences file cannot be read without that key.
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

  /// Opens (or creates) the vault. Returns null when no key material is
  /// available, in which case storage falls back to readable JSON.
  static Future<DataVault?> open() async {
    // Without a persistent keystore a fresh key each launch would make the
    // existing encrypted payloads unreadable, so fall back to plain JSON.
    if (!SecureStore.isAvailable) return null;
    try {
      final stored = await SecureStore.read(_keyName);
      final storedBytes = stored == null ? null : base64Decode(stored);
      List<int> bytes;
      if (storedBytes == null || storedBytes.length != 32) {
        final key = await _algorithm.newSecretKey();
        bytes = await key.extractBytes();
        await SecureStore.write(_keyName, base64Encode(bytes));
      } else {
        bytes = storedBytes;
      }
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
