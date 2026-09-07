import 'package:flutter/foundation.dart';
import '../models/feed_record.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/app_feedback.dart';

class FeedProvider extends ChangeNotifier {
  final List<FeedRecord> _records = [];
  final List<FeedInventory> _inventory = [];
  bool _initialized = false;

  List<FeedRecord> get records => _records;
  List<FeedInventory> get inventory => _inventory;

  double get totalFeedConsumed {
    return _records.fold(0.0, (sum, r) => sum + r.totalKg);
  }

  double get totalFeedKg => totalFeedConsumed;

  int get totalBags {
    return _records.fold(0, (sum, r) => sum + r.bagsUsed);
  }

  double get totalFeedCost {
    return _records.fold(0.0, (sum, r) => sum + r.totalCost);
  }

  /// Feed used in the last [days] days, in kg.
  double feedKgInLast(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _records
        .where((r) => r.date.isAfter(cutoff))
        .fold(0.0, (sum, r) => sum + r.totalKg);
  }

  // ── Inventory ──────────────────────────────────────────────────────

  double get totalStockKg =>
      _inventory.fold(0.0, (sum, i) => sum + i.quantityKg);

  double get totalStockValue =>
      _inventory.fold(0.0, (sum, i) => sum + i.totalValue);

  int get stockAlertCount =>
      _inventory.where((i) => i.isLowStock || i.isExpired).length;

  // Feed items already flagged this session, so an alert fires once per
  // low item rather than on every reload. Clears when an item recovers.
  final Set<String> _notifiedLowIds = {};

  /// Fires a phone notification for feed stock that is newly low or
  /// expired, so the farmer hears about it without opening the app.
  void _checkStockAlerts() {
    for (final item in _inventory) {
      final alert = item.isLowStock || item.isExpired;
      if (alert && !_notifiedLowIds.contains(item.id)) {
        _notifiedLowIds.add(item.id);
        NotificationService().showNotification(
          id: item.id.hashCode.abs() % 100000000,
          title: item.isExpired ? 'Feed expired' : 'Feed running low',
          body: item.isExpired
              ? '${item.feedTypeName} has expired. Check your feed stock.'
              : '${item.feedTypeName} is low — about ${item.quantityKg.toStringAsFixed(0)} kg left. Reorder soon.',
        );
      } else if (!alert) {
        _notifiedLowIds.remove(item.id);
      }
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  /// Re-reads state from the database. Used at startup and to roll
  /// back optimistic in-memory updates after a failed write.
  Future<void> reload() async {
    try {
      final data = await DatabaseService.instance.getAllFeedRecords();
      _records
        ..clear()
        ..addAll(data.map(FeedRecord.fromMap));
      final inv = await DatabaseService.instance.getAllFeedInventory();
      _inventory
        ..clear()
        ..addAll(inv.map(FeedInventory.fromMap));
      notifyListeners();
      _checkStockAlerts();
    } catch (e) {
      debugPrint('FeedProvider: DB load failed ($e) — running in memory.');
    }
  }

  void addFeedRecord(FeedRecord record) => addRecord(record);

  void addRecord(FeedRecord record) {
    _records.add(record);
    // Logging feed depletes the stock item it came from.
    if (record.stockItemId != null) {
      _adjustStock(record.stockItemId!, -record.totalKg);
    }
    notifyListeners();
    _persist(() => DatabaseService.instance.insertFeedRecord(record.toMap()));
  }

  void removeRecord(String id) {
    final idx = _records.indexWhere((r) => r.id == id);
    final removed = idx != -1 ? _records[idx] : null;
    _records.removeWhere((r) => r.id == id);
    // Deleting a consumption log puts the feed back into stock.
    if (removed?.stockItemId != null) {
      _adjustStock(removed!.stockItemId!, removed.totalKg);
    }
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteFeedRecord(id));
  }

  /// Moves a stock item's remaining quantity by [deltaKg] (negative to
  /// deplete when feed is used, positive to restore when a log is deleted
  /// or reduced), never below zero, and persists it.
  void _adjustStock(String stockItemId, double deltaKg) {
    final i = _inventory.indexWhere((x) => x.id == stockItemId);
    if (i == -1) return; // the stock item was deleted; nothing to adjust
    final updated = _inventory[i].copyWith(
      quantityKg: (_inventory[i].quantityKg + deltaKg).clamp(0.0, double.infinity),
    );
    _inventory[i] = updated;
    _checkStockAlerts();
    _persist(() => DatabaseService.instance.updateFeedInventory(updated.toMap()));
  }

  void removeByBatchRefs(Set<String> refs) {
    final doomed = _records.where((r) => refs.contains(r.batchId)).toList();
    if (doomed.isEmpty) return;
    _records.removeWhere((r) => refs.contains(r.batchId));
    notifyListeners();
    for (final r in doomed) {
      _persist(() => DatabaseService.instance.deleteFeedRecord(r.id));
    }
  }

  void updateRecord(FeedRecord record) {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      final old = _records[index];
      // Reverse the old draw, then apply the new one, so an edit moves
      // stock by the difference and follows a changed stock item.
      if (old.stockItemId != null) {
        _adjustStock(old.stockItemId!, old.totalKg);
      }
      _records[index] = record;
      if (record.stockItemId != null) {
        _adjustStock(record.stockItemId!, -record.totalKg);
      }
      notifyListeners();
      _persist(() => DatabaseService.instance.updateFeedRecord(record.toMap()));
    }
  }

  List<FeedRecord> getRecordsForBatch(String batchId) {
    return _records.where((r) => r.batchId == batchId).toList();
  }

  /// The stock item a feed of [type] (optionally named [feedName]) should
  /// be drawn from, so a consumption log depletes the right bag. Matches
  /// first on the type keyword the stock name carries (starter, grower,
  /// layer, finisher) so "Chick Starter" finds "Starter Mash", then a
  /// looser name match; null when nothing matches (do not guess-deplete).
  String? stockIdFor(FeedType type, {String? feedName}) {
    if (_inventory.isEmpty) return null;
    final keyword = switch (type) {
      FeedType.starter => 'starter',
      FeedType.grower => 'grower',
      FeedType.layer => 'layer',
      FeedType.finisher => 'finisher',
      FeedType.custom => null,
    };
    if (keyword != null) {
      for (final it in _inventory) {
        if (it.feedTypeName.toLowerCase().contains(keyword)) return it.id;
      }
    }
    if (feedName != null && feedName.trim().isNotEmpty) {
      final f = feedName.toLowerCase();
      for (final it in _inventory) {
        final n = it.feedTypeName.toLowerCase();
        if (n == f || n.contains(f) || f.contains(n)) return it.id;
      }
    }
    return null;
  }

  void addToInventory(FeedInventory item) {
    _inventory.add(item);
    notifyListeners();
    _checkStockAlerts();
    _persist(() => DatabaseService.instance.insertFeedInventory(item.toMap()));
  }

  void updateInventory(FeedInventory item) {
    final index = _inventory.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _inventory[index] = item;
      notifyListeners();
      _checkStockAlerts();
      _persist(
        () => DatabaseService.instance.updateFeedInventory(item.toMap()),
      );
    }
  }

  void removeInventory(String id) {
    _inventory.removeWhere((i) => i.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteFeedInventory(id));
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _records
      ..clear()
      ..addAll(data.map(FeedRecord.fromMap));
    notifyListeners();
  }

  /// Write-through persistence: awaits the DB write and, if it
  /// fails, reloads state from the database (undoing the optimistic
  /// update) and tells the user instead of failing silently.
  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('FeedProvider: DB write failed: $e');
      showAppError(
        'Could not save — the change was not stored. Please try again.',
      );
      await reload();
    }
  }
}
