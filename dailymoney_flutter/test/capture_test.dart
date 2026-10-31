import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/models/detection.dart';
import 'package:dailymoney/models/tx.dart';
import 'package:dailymoney/providers/capture_provider.dart';
import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/providers/transactions_provider.dart';
import 'package:dailymoney/services/storage_service.dart';

Detection detection(
  String id, {
  double amount = 250,
  TxType type = TxType.expense,
  DateTime? at,
  String title = 'Paid to Blinkit',
}) =>
    Detection(
      id: id,
      packageName: 'com.example.pay',
      appLabel: 'Example Pay',
      title: title,
      text: 'You paid ₹$amount to Blinkit',
      amount: amount,
      type: type,
      capturedAt: at ?? DateTime(2026, 10, 15, 9),
    );

Future<StorageService> emptyStorage() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('converts native UTC capture times to local time', () {
    final utc = DateTime.utc(2026, 10, 28, 6, 42);
    final parsed = Detection.fromJson({
      'id': 'utc',
      'packageName': 'com.example.pay',
      'appLabel': 'Example Pay',
      'title': 'Paid',
      'text': 'You paid ₹10',
      'amount': 10,
      'type': 'expense',
      'capturedAt': utc.toIso8601String(),
    });

    expect(parsed.capturedAt.isUtc, isFalse);
    expect(parsed.capturedAt, utc.toLocal());
    expect(parsed.toJson()['capturedAt'], endsWith('Z'));
  });

  test('loads the native queue, dedupes, persists and clears it', () async {
    final storage = await emptyStorage();
    final stored = detection('a', at: DateTime(2026, 10, 14, 8));
    await storage.saveDetections([stored]);

    final fresh = detection('b', at: DateTime(2026, 10, 15, 9));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode([fresh.toJson(), stored.toJson()]),
    );

    final capture = CaptureProvider(storage);
    await capture.load();

    expect(capture.count, 2, reason: 'duplicate id is merged once');
    expect(capture.all.first.id, 'b');
    expect(prefs.getString('dm.capture.queue.v1'), isNull);

    final persisted = await storage.loadDetections();
    expect(persisted.map((d) => d.id).toSet(), {'a', 'b'});
  });

  test('a second load is stable and only adds new detections', () async {
    final storage = await emptyStorage();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode([detection('one').toJson()]),
    );

    final capture = CaptureProvider(storage);
    await capture.load();
    await capture.load();

    expect(capture.count, 1);

    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode([detection('two', at: DateTime(2026, 10, 16)).toJson()]),
    );
    await capture.refresh();

    expect(capture.count, 2);
    expect(capture.all.first.id, 'two');
  });

  test('queued snippets are dropped after detection is turned off', () async {
    final storage = await emptyStorage();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode([detection('queued').toJson()]),
    );

    final capture = CaptureProvider(storage);
    await capture.load(acceptNative: false);

    expect(capture.isEmpty, isTrue);
    expect(prefs.getString('dm.capture.queue.v1'), isNull);
    expect(await storage.loadDetections(), isEmpty);
  });

  test('caps the review queue at 40 entries, newest first', () async {
    final storage = await emptyStorage();
    final prefs = await SharedPreferences.getInstance();
    final many = List.generate(
      45,
      (i) => detection(
        'd$i',
        at: DateTime(2026, 10, 1).add(Duration(hours: i)),
      ),
    );
    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode(many.map((d) => d.toJson()).toList()),
    );

    final capture = CaptureProvider(storage);
    await capture.load();

    expect(capture.count, 40);
    expect(capture.all.first.id, 'd44');
    expect(capture.all.last.id, 'd5');
    expect((await storage.loadDetections()).length, 40);
  });

  test('pending total counts expenses only', () async {
    final storage = await emptyStorage();
    final capture = CaptureProvider(storage);
    await capture.load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode([
        detection('out', amount: 250).toJson(),
        detection('in', amount: 500, type: TxType.income).toJson(),
      ]),
    );

    await capture.refresh();

    expect(capture.count, 2);
    expect(capture.pendingExpenseTotal, 250);
  });

  test('accepting a detection records it and removes it from review', () async {
    final storage = await emptyStorage();
    final capture = CaptureProvider(storage);
    await capture.load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode([detection('pay', amount: 349.5).toJson()]),
    );
    await capture.refresh();

    final txs = TransactionsProvider(storage);
    await txs.load();
    final tx = await capture.accept(capture.all.single, txs);

    expect(capture.count, 0);
    expect(txs.count, 1);
    expect(tx.amount, 349.5);
    expect(tx.type, TxType.expense);
    expect(tx.title, 'Paid to Blinkit');
    expect(tx.note, 'Detected in Example Pay');
    expect(tx.date, DateTime(2026, 10, 15, 9));
    expect(await storage.loadDetections(), isEmpty);
  });

  test('ignoring a detection drops it without touching the ledger', () async {
    final storage = await emptyStorage();
    final capture = CaptureProvider(storage);
    await capture.load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode([detection('pay').toJson()]),
    );
    await capture.refresh();

    await capture.ignore('pay');

    expect(capture.isEmpty, isTrue);
    expect(await storage.loadDetections(), isEmpty);
  });

  test('the automatic-tracking switch is mirrored for the listener', () async {
    final storage = await emptyStorage();
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(storage);
    await settings.load();
    expect(prefs.getBool('dm.capture.enabled'), isFalse);

    await settings.setAutoCapture(true);
    expect(prefs.getBool('dm.capture.enabled'), isTrue);

    // Reloading settings mirrors the stored preference again.
    final reloaded = SettingsProvider(storage);
    await reloaded.load();
    expect(reloaded.autoCapture, isTrue);
    expect(prefs.getBool('dm.capture.enabled'), isTrue);

    await reloaded.resetToDefaults();
    expect(prefs.getBool('dm.capture.enabled'), isFalse);
  });

  test('wiping data removes the queue, flag and detections', () async {
    final storage = await emptyStorage();
    final prefs = await SharedPreferences.getInstance();
    await storage.saveDetections([detection('saved')]);
    await storage.setCaptureEnabled(true);
    await prefs.setString(
      'dm.capture.queue.v1',
      jsonEncode([detection('native').toJson()]),
    );

    await storage.clearAll();

    expect(prefs.getString('dm.capture.queue.v1'), isNull);
    expect(prefs.getBool('dm.capture.enabled'), isNull);
    expect(await storage.loadDetections(), isEmpty);
  });
}
