import 'package:flutter/foundation.dart';
import '../models/egg_production.dart';

class EggProductionProvider extends ChangeNotifier {
  final List<EggProduction> _records = [];

  List<EggProduction> get records => _records;

  int get todayCount {
    final today = DateTime.now();
    return _records
        .where(
          (e) =>
              e.date.year == today.year &&
              e.date.month == today.month &&
              e.date.day == today.day,
        )
        .fold(0, (sum, e) => sum + e.eggCount);
  }

  int get totalEggs {
    return _records.fold(0, (sum, e) => sum + e.eggCount);
  }

  int get totalDamagedEggs {
    return _records.fold(0, (sum, e) => sum + e.damagedCount);
  }

  double get totalRevenue {
    return _records.fold(0.0, (sum, e) => sum + e.revenue);
  }

  double get averagePerDay {
    if (_records.isEmpty) return 0.0;
    return totalEggs / _records.length;
  }

  void addRecord(EggProduction record) {
    _records.add(record);
    notifyListeners();
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void updateRecord(EggProduction record) {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
      notifyListeners();
    }
  }

  List<EggProduction> getRecordsForBatch(String batchId) {
    return _records.where((r) => r.batchId == batchId).toList();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _records.clear();
    for (var map in data) {
      _records.add(EggProduction.fromMap(map));
    }
    notifyListeners();
  }

  Future<void> loadAllRecords() async {
    notifyListeners();
  }
}
