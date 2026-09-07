import 'package:flutter/foundation.dart';
import '../models/measurement.dart';
import '../services/database_service.dart';
import '../utils/app_feedback.dart';

/// Flock readings: weight, temperature and water. All three share one
/// table, kept apart by [Measurement.type].
class MeasurementProvider extends ChangeNotifier {
  final List<Measurement> _records = [];
  bool _initialized = false;

  List<Measurement> get records => _records;

  /// Readings for one batch of one [type], oldest first — the shape the
  /// trend charts want.
  List<Measurement> series(String batchId, MeasurementType type) {
    final rows = _records
        .where((m) => m.batchId == batchId && m.type == type)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return rows;
  }

  /// All of a batch's readings, newest first, for the history list.
  List<Measurement> forBatch(String batchId) {
    final rows = _records.where((m) => m.batchId == batchId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  /// The most recent reading of [type] for a batch, or null.
  Measurement? latest(String batchId, MeasurementType type) {
    final s = series(batchId, type);
    return s.isEmpty ? null : s.last;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  Future<void> reload() async {
    try {
      final data = await DatabaseService.instance.getAllMeasurements();
      _records
        ..clear()
        ..addAll(data.map(Measurement.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint('MeasurementProvider: DB load failed ($e) — running in memory.');
    }
  }

  void addRecord(Measurement m) {
    _records.add(m);
    notifyListeners();
    _persist(() => DatabaseService.instance.insertMeasurement(m.toMap()));
  }

  void updateRecord(Measurement m) {
    final i = _records.indexWhere((r) => r.id == m.id);
    if (i != -1) {
      _records[i] = m;
      notifyListeners();
      _persist(() => DatabaseService.instance.updateMeasurement(m.toMap()));
    }
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteMeasurement(id));
  }

  void removeByBatchRefs(Set<String> refs) {
    final doomed = _records.where((r) => refs.contains(r.batchId)).toList();
    if (doomed.isEmpty) return;
    _records.removeWhere((r) => refs.contains(r.batchId));
    notifyListeners();
    for (final r in doomed) {
      _persist(() => DatabaseService.instance.deleteMeasurement(r.id));
    }
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _records
      ..clear()
      ..addAll(data.map(Measurement.fromMap));
    notifyListeners();
  }

  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('MeasurementProvider: DB write failed: $e');
      showAppError('Could not save — the change was not stored. Please try again.');
      await reload();
    }
  }
}
