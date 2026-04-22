import 'package:flutter/foundation.dart';
import '../models/mortality.dart';

class MortalityProvider extends ChangeNotifier {
  final List<Mortality> _records = [];

  List<Mortality> get records => _records;

  int get totalCount {
    return _records.fold(0, (sum, m) => sum + m.count);
  }

  double get mortalityRate {
    if (_records.isEmpty) return 0.0;
    return totalCount.toDouble();
  }

  void addRecord(Mortality mortality) {
    _records.add(mortality);
    notifyListeners();
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void updateRecord(Mortality record) {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
      notifyListeners();
    }
  }

  List<Mortality> getRecordsForBatch(String batchId) {
    return _records.where((r) => r.batchId == batchId).toList();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _records.clear();
    for (var map in data) {
      _records.add(Mortality.fromMap(map));
    }
    notifyListeners();
  }

  Future<void> loadAllRecords() async {
    notifyListeners();
  }
}
