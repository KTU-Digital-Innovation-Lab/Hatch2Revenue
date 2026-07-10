import 'package:flutter/foundation.dart';
import '../models/mortality.dart';
import '../services/database_service.dart';
import '../utils/app_feedback.dart';

class MortalityProvider extends ChangeNotifier {
  final List<Mortality> _records = [];
  bool _initialized = false;

  List<Mortality> get records => _records;

  int get totalCount {
    return _records.fold(0, (sum, m) => sum + m.count);
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
      final data = await DatabaseService.instance.getAllMortality();
      _records
        ..clear()
        ..addAll(data.map(Mortality.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint(
        'MortalityProvider: DB load failed ($e) — running in memory.',
      );
    }
  }

  void addRecord(Mortality mortality) {
    _records.add(mortality);
    notifyListeners();
    _persist(() => DatabaseService.instance.insertMortality(mortality.toMap()));
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteMortality(id));
  }

  void removeByBatchRefs(Set<String> refs) {
    final doomed = _records.where((r) => refs.contains(r.batchId)).toList();
    if (doomed.isEmpty) return;
    _records.removeWhere((r) => refs.contains(r.batchId));
    notifyListeners();
    for (final r in doomed) {
      _persist(() => DatabaseService.instance.deleteMortality(r.id));
    }
  }

  void updateRecord(Mortality record) {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
      notifyListeners();
      _persist(() => DatabaseService.instance.updateMortality(record.toMap()));
    }
  }

  List<Mortality> getRecordsForBatch(String batchId) {
    return _records.where((r) => r.batchId == batchId).toList();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _records
      ..clear()
      ..addAll(data.map(Mortality.fromMap));
    notifyListeners();
  }

  /// Write-through persistence: awaits the DB write and, if it
  /// fails, reloads state from the database (undoing the optimistic
  /// update) and tells the user instead of failing silently.
  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('MortalityProvider: DB write failed: $e');
      showAppError(
        'Could not save — the change was not stored. Please try again.',
      );
      await reload();
    }
  }
}
