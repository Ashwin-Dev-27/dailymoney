import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../services/secure_store.dart';
import '../services/storage_service.dart';

/// App-lock state: PIN, optional biometrics and auto-lock timing.
///
/// Only a PBKDF2-HMAC-SHA256 digest of the PIN is kept, and it lives in the
/// Android Keystore via [SecureStore]. The PIN itself is never written to disk.
/// Older salted SHA-256 records are still accepted and are upgraded in place
/// after the next successful unlock.
class SecurityProvider extends ChangeNotifier {
  SecurityProvider(this._storage, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final StorageService _storage;
  final LocalAuthentication _auth = LocalAuthentication();

  /// Injectable clock so lockout expiry can be tested without waiting.
  final DateTime Function() _clock;

  static const String _pinKey = 'dm.pin.v1';
  static const int pinLength = 4;

  /// Wrong PINs allowed before a cooldown starts.
  static const int maxPinAttempts = 5;

  /// Progressive cooldowns. The last entry repeats for later failures.
  static const List<Duration> pinLockoutSchedule = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  /// Work factor for new PIN records. High enough to make a copied digest
  /// expensive to brute-force, low enough for a phone to unlock quickly.
  static const int _pinIterations = 100000;
  static const String _pinVersion = 'v2';

  static final Pbkdf2 _pinKdf =
      Pbkdf2.hmacSha256(iterations: _pinIterations, bits: 256);

  bool pinEnabled = false;
  bool biometricEnabled = false;
  bool biometricAvailable = false;
  bool locked = false;

  /// 0 means lock as soon as the app leaves the foreground.
  int autoLockSeconds = 0;

  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  int get failedPinAttempts => _failedPinAttempts;

  /// When the current cooldown ends, or null when PIN entry is allowed.
  DateTime? get pinLockedUntil => _pinLockedUntil;

  bool get pinLockedOut =>
      _pinLockedUntil != null && _pinLockedUntil!.isAfter(_clock());

  Duration get pinLockoutRemaining {
    final until = _pinLockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> load() async {
    final flags = await _storage.loadSecurity();
    final stored = await SecureStore.read(_pinKey);
    pinEnabled = flags['pinEnabled'] == true && _isPinRecord(stored);
    biometricEnabled = pinEnabled && flags['biometricEnabled'] == true;
    autoLockSeconds = (flags['autoLockSeconds'] as num?)?.toInt() ?? 0;
    if (autoLockSeconds < 0) autoLockSeconds = 0;
    _failedPinAttempts = (flags['pinFailedAttempts'] as num?)?.toInt() ?? 0;
    if (_failedPinAttempts < 0) _failedPinAttempts = 0;
    final lockedUntilMs = (flags['pinLockedUntilMs'] as num?)?.toInt();
    _pinLockedUntil = lockedUntilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockedUntilMs);
    locked = pinEnabled;
    notifyListeners();
    if (!SecureStore.isTest) unawaited(_detectBiometrics());
  }

  Future<void> _detectBiometrics() async {
    var available = false;
    try {
      available = await _auth.canCheckBiometrics;
      available = available && await _auth.isDeviceSupported();
    } catch (_) {
      available = false;
    }
    if (available != biometricAvailable) {
      biometricAvailable = available;
      notifyListeners();
    }
  }

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(16);
    final hash = await _derivePin(pin, salt, _pinIterations);
    await SecureStore.write(
      _pinKey,
      '$_pinVersion:$_pinIterations:${base64Encode(salt)}:$hash',
    );
    pinEnabled = true;
    locked = false;
    _clearLockoutState();
    await _persist();
    notifyListeners();
  }

  /// Changes the PIN after the caller has already verified the old one.
  ///
  /// Wrong entries count towards the progressive cooldown. While a cooldown is
  /// active this returns false without touching the stored PIN, so a caller
  /// cannot bypass the delay by guessing in a loop.
  Future<bool> verifyPin(String pin) async {
    if (pinLockedOut) return false;
    final stored = await SecureStore.read(_pinKey);
    if (stored == null) return false;
    final parts = stored.split(':');
    var ok = false;
    try {
      if (parts.length == 4 && parts[0] == _pinVersion) {
        final iterations = int.tryParse(parts[1]);
        if (iterations == null || iterations < 1000 || iterations > 1000000) {
          return false;
        }
        final salt = base64Decode(parts[2]);
        final actual = await _derivePin(pin, salt, iterations);
        ok = _constantTimeEquals(actual, parts[3]);
        if (ok && iterations != _pinIterations) {
          await _upgradePin(pin);
        }
      } else if (parts.length == 2) {
        // Legacy record: base64(salt):base64(SHA-256(salt + PIN)).
        final salt = base64Decode(parts[0]);
        final actual = await _hashLegacyPin(pin, salt);
        ok = _constantTimeEquals(actual, parts[1]);
        if (ok) await _upgradePin(pin);
      }
    } catch (_) {
      ok = false;
    }

    if (ok) {
      await _clearFailedPinAttempts();
    } else {
      await _registerFailedPinAttempt();
    }
    return ok;
  }

  /// Rewrites a verified legacy/old-work-factor record with the current KDF.
  Future<void> _upgradePin(String pin) async {
    final salt = _randomBytes(16);
    final hash = await _derivePin(pin, salt, _pinIterations);
    await SecureStore.write(
      _pinKey,
      '$_pinVersion:$_pinIterations:${base64Encode(salt)}:$hash',
    );
  }

  Future<void> disablePin() async {
    await SecureStore.delete(_pinKey);
    pinEnabled = false;
    biometricEnabled = false;
    locked = false;
    _clearLockoutState();
    await _persist();
    notifyListeners();
  }

  /// Enables biometrics after a successful scan; returns whether it is on.
  Future<bool> setBiometric(bool enabled) async {
    if (!pinEnabled) return false;
    if (!enabled) {
      biometricEnabled = false;
      await _persist();
      notifyListeners();
      return true;
    }
    if (!biometricAvailable) return false;
    final ok = await authenticateBiometric();
    if (!ok) return false;
    biometricEnabled = true;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Prompts for a fingerprint / face scan. Unlocks on success.
  Future<bool> authenticateBiometric() async {
    if (!biometricAvailable) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock DailyMoney',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (ok) unlock();
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    autoLockSeconds = max(0, seconds);
    await _persist();
    notifyListeners();
  }

  void lock() {
    if (!pinEnabled || locked) return;
    locked = true;
    notifyListeners();
  }

  void unlock() {
    if (!locked) return;
    locked = false;
    notifyListeners();
  }

  /// Removes the PIN and all lock settings (used by "forgot PIN" reset).
  Future<void> resetAll() async {
    await SecureStore.delete(_pinKey);
    pinEnabled = false;
    biometricEnabled = false;
    locked = false;
    autoLockSeconds = 0;
    _clearLockoutState();
    await _storage.saveSecurity(const {});
    notifyListeners();
  }

  Future<void> _registerFailedPinAttempt() async {
    _failedPinAttempts++;
    if (_failedPinAttempts >= maxPinAttempts) {
      final tier = (_failedPinAttempts - maxPinAttempts)
          .clamp(0, pinLockoutSchedule.length - 1);
      _pinLockedUntil = _clock().add(pinLockoutSchedule[tier]);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _clearFailedPinAttempts() async {
    final hadFailure = _failedPinAttempts != 0 || _pinLockedUntil != null;
    _clearLockoutState();
    if (hadFailure) {
      await _persist();
      notifyListeners();
    }
  }

  void _clearLockoutState() {
    _failedPinAttempts = 0;
    _pinLockedUntil = null;
  }

  Future<void> _persist() => _storage.saveSecurity({
        'pinEnabled': pinEnabled,
        'biometricEnabled': biometricEnabled,
        'autoLockSeconds': autoLockSeconds,
        'pinFailedAttempts': _failedPinAttempts,
        'pinLockedUntilMs': _pinLockedUntil?.millisecondsSinceEpoch,
      });

  static List<int> _randomBytes(int length) {
    final rnd = Random.secure();
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }

  static bool _isPinRecord(String? stored) {
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length == 2) return true;
    return parts.length == 4 &&
        parts[0] == _pinVersion &&
        int.tryParse(parts[1]) != null;
  }

  static Future<String> _derivePin(
    String pin,
    List<int> salt,
    int iterations,
  ) async {
    final kdf = iterations == _pinIterations
        ? _pinKdf
        : Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
    final key = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return base64Encode(await key.extractBytes());
  }

  /// The pre-1.3.1 format, kept only to verify and then replace old records.
  static Future<String> _hashLegacyPin(String pin, List<int> salt) async {
    final digest = await Sha256().hash([...salt, ...utf8.encode(pin)]);
    return base64Encode(digest.bytes);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
