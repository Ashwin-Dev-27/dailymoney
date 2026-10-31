import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/providers/security_provider.dart';
import 'package:dailymoney/services/data_vault.dart';
import 'package:dailymoney/services/secure_store.dart';
import 'package:dailymoney/services/storage_service.dart';

Future<SecurityProvider> providerOn(StorageService storage) async {
  final security = SecurityProvider(storage);
  await security.load();
  return security;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SecureStore.delete('dm.pin.v1');
    await SecureStore.delete('dm.vault.key.v1');
  });

  test('PIN is disabled until one is set', () async {
    final storage = StorageService();
    await storage.init();
    final security = await providerOn(storage);

    expect(security.pinEnabled, isFalse);
    expect(security.locked, isFalse);
    expect(await security.verifyPin('1234'), isFalse);
  });

  test('a set PIN verifies, hashes, and survives a reload', () async {
    final storage = StorageService();
    await storage.init();
    final security = await providerOn(storage);

    await security.setPin('1234');

    expect(security.pinEnabled, isTrue);
    expect(security.locked, isFalse);
    expect(await security.verifyPin('1234'), isTrue);
    expect(await security.verifyPin('4321'), isFalse);

    final stored = await SecureStore.read('dm.pin.v1');
    expect(stored, isNotNull);
    expect(stored, contains(':'));
    expect(stored, isNot(contains('1234')));

    // A fresh launch with a PIN must start locked.
    final reloaded = await providerOn(storage);
    expect(reloaded.pinEnabled, isTrue);
    expect(reloaded.locked, isTrue);
    expect(await reloaded.verifyPin('1234'), isTrue);
  });

  test('new PIN records use the versioned PBKDF2 format', () async {
    final storage = StorageService();
    await storage.init();
    final security = await providerOn(storage);

    await security.setPin('1234');

    final stored = await SecureStore.read('dm.pin.v1');
    final parts = stored!.split(':');
    expect(parts, hasLength(4));
    expect(parts[0], 'v2');
    expect(int.parse(parts[1]), greaterThanOrEqualTo(100000));
    expect(base64Decode(parts[2]), hasLength(16));
    expect(base64Decode(parts[3]), hasLength(32));
  });

  test('legacy SHA-256 PIN records verify once and upgrade in place', () async {
    final salt = List<int>.generate(16, (i) => i + 1);
    final digest = await Sha256().hash([...salt, ...utf8.encode('2468')]);
    final legacy = '${base64Encode(salt)}:${base64Encode(digest.bytes)}';

    final storage = StorageService();
    await storage.init();
    await storage.saveSecurity({'pinEnabled': true});
    await SecureStore.write('dm.pin.v1', legacy);

    final security = await providerOn(storage);
    expect(security.pinEnabled, isTrue);

    // A wrong PIN leaves the old record untouched.
    expect(await security.verifyPin('0000'), isFalse);
    expect(await SecureStore.read('dm.pin.v1'), legacy);

    expect(await security.verifyPin('2468'), isTrue);
    final upgraded = await SecureStore.read('dm.pin.v1');
    expect(upgraded, startsWith('v2:'));
    expect(upgraded, isNot(legacy));
    expect(await security.verifyPin('2468'), isTrue);
  });

  test('stale flags without key material do not lock the app', () async {
    final storage = StorageService();
    await storage.init();
    await storage.saveSecurity({'pinEnabled': true, 'biometricEnabled': true});

    final security = await providerOn(storage);

    expect(security.pinEnabled, isFalse);
    expect(security.locked, isFalse);
  });

  test('lock and unlock only act when a PIN exists', () async {
    final storage = StorageService();
    await storage.init();
    final security = await providerOn(storage);

    security.unlock();
    security.lock();
    expect(security.locked, isFalse);
    await security.setPin('1111');

    security.lock();
    expect(security.locked, isTrue);
    security.unlock();
    expect(security.locked, isFalse);

    await security.disablePin();
    expect(security.pinEnabled, isFalse);
    expect(await SecureStore.read('dm.pin.v1'), isNull);
    security.lock();
    expect(security.locked, isFalse);
  });

  test('auto-lock setting is persisted and never negative', () async {
    final storage = StorageService();
    await storage.init();
    final security = await providerOn(storage);

    await security.setAutoLockSeconds(60);
    expect(security.autoLockSeconds, 60);

    await security.setAutoLockSeconds(-5);
    expect(security.autoLockSeconds, 0);

    final reloaded = await providerOn(storage);
    expect(reloaded.autoLockSeconds, 0);

    await security.resetAll();
    final afterReset = await providerOn(storage);
    expect(afterReset.pinEnabled, isFalse);
    expect(afterReset.biometricEnabled, isFalse);
    expect(afterReset.autoLockSeconds, 0);
  });

  test('biometrics cannot be enabled without availability', () async {
    final storage = StorageService();
    await storage.init();
    final security = await providerOn(storage);

    expect(await security.setBiometric(true), isFalse);

    await security.setPin('1234');
    // No biometric hardware in the test environment.
    expect(security.biometricAvailable, isFalse);
    expect(await security.setBiometric(true), isFalse);
    expect(await security.authenticateBiometric(), isFalse);

    expect(await security.setBiometric(false), isTrue);
    expect(security.biometricEnabled, isFalse);
  });

  test('vault round-trips AES-GCM payloads and rejects a wrong key', () async {
    final key = List<int>.generate(32, (i) => i);
    final vault = DataVault.fromKeyBytes(key);

    final sealed = await vault.encrypt('{"budget":1234.5}');

    expect(vault.isEncrypted(sealed), isTrue);
    expect(sealed, startsWith('enc1:'));
    expect(sealed, isNot(contains('budget')));
    expect(await vault.decrypt(sealed), '{"budget":1234.5}');

    final other =
        DataVault.fromKeyBytes(List<int>.generate(32, (i) => 255 - i));
    expect(other.decrypt(sealed), throwsA(anything));
  });

  test('vault falls back to plain storage without a keystore', () async {
    // Tests run without platform channels, so there is no durable key.
    expect(await DataVault.open(), isNull);

    final storage = StorageService();
    await storage.init();
    expect(storage.encryptionEnabled, isFalse);
  });

  test('upgrading encrypts existing plaintext payloads in place', () async {
    final oldTx = Tx(
      id: 'old',
      title: 'Old tx',
      amount: 12.5,
      type: TxType.expense,
      categoryId: 'food',
      date: DateTime(2026, 10, 1),
    );
    SharedPreferences.setMockInitialValues({
      'dm.transactions.v1': jsonEncode([oldTx.toJson()]),
      'dm.settings.v1': jsonEncode({'monthlyBudget': 500.0}),
    });

    final storage = StorageService();
    await storage.init(
      vaultOverride: DataVault.fromKeyBytes(List<int>.generate(32, (i) => i)),
    );

    final prefs = await SharedPreferences.getInstance();
    final rawTx = prefs.getString('dm.transactions.v1');
    final rawSettings = prefs.getString('dm.settings.v1');
    expect(storage.encryptionEnabled, isTrue);
    expect(rawTx, startsWith('enc1:'));
    expect(rawSettings, startsWith('enc1:'));
    expect(rawTx, isNot(contains('Old tx')));

    expect((await storage.loadTransactions()).single.title, 'Old tx');
    expect((await storage.loadSettings())['monthlyBudget'], 500.0);

    // A second init does not double-encrypt the payload.
    await storage.init(
      vaultOverride: DataVault.fromKeyBytes(List<int>.generate(32, (i) => i)),
    );
    expect(prefs.getString('dm.transactions.v1'), rawTx);
    expect((await storage.loadTransactions()).single.amount, 12.5);
  });

  test('wrong PINs trigger a persisted progressive cooldown', () async {
    var now = DateTime(2026, 10, 30, 12);
    final storage = StorageService();
    await storage.init();
    final security = SecurityProvider(storage, clock: () => now);
    await security.load();
    await security.setPin('1234');

    for (var i = 0; i < SecurityProvider.maxPinAttempts; i++) {
      expect(await security.verifyPin('0000'), isFalse);
    }

    expect(security.pinLockedOut, isTrue);
    expect(security.failedPinAttempts, SecurityProvider.maxPinAttempts);
    expect(security.pinLockoutRemaining, const Duration(seconds: 30));
    // Even the correct PIN is refused while the cooldown is active.
    expect(await security.verifyPin('1234'), isFalse);

    final reloaded = SecurityProvider(storage, clock: () => now);
    await reloaded.load();
    expect(reloaded.pinLockedOut, isTrue);

    now = now.add(const Duration(seconds: 31));
    expect(reloaded.pinLockedOut, isFalse);

    // The next wrong attempt escalates instead of restarting at 30 seconds.
    expect(await reloaded.verifyPin('0000'), isFalse);
    expect(reloaded.failedPinAttempts, SecurityProvider.maxPinAttempts + 1);
    expect(reloaded.pinLockoutRemaining, const Duration(minutes: 1));

    now = now.add(const Duration(minutes: 1, seconds: 1));
    expect(await reloaded.verifyPin('1234'), isTrue);
    expect(reloaded.failedPinAttempts, 0);
    expect(reloaded.pinLockedOut, isFalse);
  });

  test('a correct PIN clears earlier failed attempts', () async {
    final storage = StorageService();
    await storage.init();
    final security = SecurityProvider(storage);
    await security.load();
    await security.setPin('1234');

    expect(await security.verifyPin('0000'), isFalse);
    expect(await security.verifyPin('0000'), isFalse);
    expect(security.failedPinAttempts, 2);

    expect(await security.verifyPin('1234'), isTrue);
    expect(security.failedPinAttempts, 0);
    expect(security.pinLockedOut, isFalse);
  });

  test('resetAll clears a cooldown and removes the PIN', () async {
    var now = DateTime(2026, 10, 30, 12);
    final storage = StorageService();
    await storage.init();
    final security = SecurityProvider(storage, clock: () => now);
    await security.load();
    await security.setPin('1234');

    for (var i = 0; i < SecurityProvider.maxPinAttempts; i++) {
      await security.verifyPin('0000');
    }
    expect(security.pinLockedOut, isTrue);

    await security.resetAll();
    expect(security.pinEnabled, isFalse);
    expect(security.pinLockedOut, isFalse);
    expect(security.failedPinAttempts, 0);
    expect(await storage.loadSecurity(), isEmpty);
  });
}
