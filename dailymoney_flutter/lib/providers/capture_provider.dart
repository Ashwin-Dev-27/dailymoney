import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/detection.dart';
import '../models/tx.dart';
import '../services/storage_service.dart';
import 'transactions_provider.dart';

/// Pending payments captured from other apps' notifications.
class CaptureProvider extends ChangeNotifier {
  CaptureProvider(this._storage);

  final StorageService _storage;
  final List<Detection> _items = [];

  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;

  double get pendingExpenseTotal => _items
      .where((d) => d.type.isExpense)
      .fold(0.0, (sum, d) => sum + d.amount);

  /// Newest first.
  List<Detection> get all {
    final list = List<Detection>.from(_items)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(list);
  }

  Future<void> load({bool acceptNative = true}) async {
    final stored = await _storage.loadDetections();
    final native = await _storage.takeNativeDetections();
    _items
      ..clear()
      ..addAll(stored);
    final ids = _items.map((d) => d.id).toSet();
    var added = false;
    for (final detection in native) {
      // The queue is always cleared, but snippets captured before payment
      // detection was turned off are dropped instead of imported.
      if (!acceptNative) continue;
      if (ids.add(detection.id)) {
        _items.add(detection);
        added = true;
      }
    }
    // Keep the queue manageable even after a long stretch away from the app.
    if (_items.length > 40) {
      final sorted = List<Detection>.from(_items)
        ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      _items
        ..clear()
        ..addAll(sorted.take(40));
      added = true;
    }
    notifyListeners();
    if (added) await _storage.saveDetections(_items);
  }

  /// Re-reads the queue written by the Android notification listener.
  Future<void> refresh({bool acceptNative = true}) =>
      load(acceptNative: acceptNative);

  Future<void> ignore(String id) async {
    _items.removeWhere((d) => d.id == id);
    notifyListeners();
    await _storage.saveDetections(_items);
  }

  /// Commits a detected payment to the ledger, then removes it from the queue.
  Future<Tx> accept(Detection detection, TransactionsProvider txs) async {
    final tx = Tx(
      id: const Uuid().v4(),
      title: detection.ledgerTitle,
      amount: detection.amount,
      type: detection.type,
      categoryId: detection.categoryId,
      date: detection.capturedAt,
      note: 'Detected in ${detection.appLabel}',
    );
    await txs.add(tx);
    _items.removeWhere((d) => d.id == detection.id);
    notifyListeners();
    await _storage.saveDetections(_items);
    return tx;
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _storage.saveDetections(_items);
  }
}
