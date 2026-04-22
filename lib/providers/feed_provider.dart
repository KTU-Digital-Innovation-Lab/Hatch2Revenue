import 'package:flutter/foundation.dart';
import '../models/feed_record.dart';

class FeedProvider extends ChangeNotifier {
  final List<FeedRecord> _records = [];
  final List<FeedInventory> _inventory = [];

  List<FeedRecord> get records => _records;
  List<FeedInventory> get inventory => _inventory;

  double get totalFeedConsumed {
    return _records.fold(0.0, (sum, r) => sum + r.totalKg);
  }

  double get totalFeedKg {
    return _records.fold(0.0, (sum, r) => sum + r.totalKg);
  }

  int get totalBags {
    return _records.fold(0, (sum, r) => sum + r.bagsUsed);
  }

  double get totalFeedCost {
    return _records.fold(0.0, (sum, r) => sum + r.totalCost);
  }

  double get averageFCR {
    return 0.0;
  }

  void addFeedRecord(FeedRecord record) {
    _records.add(record);
    notifyListeners();
  }

  void addRecord(FeedRecord record) {
    _records.add(record);
    notifyListeners();
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void updateRecord(FeedRecord record) {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
      notifyListeners();
    }
  }

  List<FeedRecord> getRecordsForBatch(String batchId) {
    return _records.where((r) => r.batchId == batchId).toList();
  }

  void addToInventory(FeedInventory item) {
    _inventory.add(item);
    notifyListeners();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _records.clear();
    for (var map in data) {
      _records.add(FeedRecord.fromMap(map));
    }
    notifyListeners();
  }

  Future<void> loadAllRecords() async {
    notifyListeners();
  }
}
