import 'package:flutter/foundation.dart';
import '../models/feed_record.dart';
import '../services/database_service.dart';
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
    } catch (e) {
      debugPrint('FeedProvider: DB load failed ($e) — running in memory.');
    }
  }

  void addFeedRecord(FeedRecord record) => addRecord(record);

  void addRecord(FeedRecord record) {
    _records.add(record);
    notifyListeners();
    _persist(() => DatabaseService.instance.insertFeedRecord(record.toMap()));
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteFeedRecord(id));
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
      _records[index] = record;
      notifyListeners();
      _persist(() => DatabaseService.instance.updateFeedRecord(record.toMap()));
    }
  }

  List<FeedRecord> getRecordsForBatch(String batchId) {
    return _records.where((r) => r.batchId == batchId).toList();
  }

  void addToInventory(FeedInventory item) {
    _inventory.add(item);
    notifyListeners();
    _persist(() => DatabaseService.instance.insertFeedInventory(item.toMap()));
  }

  void updateInventory(FeedInventory item) {
    final index = _inventory.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _inventory[index] = item;
      notifyListeners();
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
