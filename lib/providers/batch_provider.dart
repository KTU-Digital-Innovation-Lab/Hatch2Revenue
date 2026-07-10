import 'package:flutter/foundation.dart';
import '../models/batch.dart';
import '../services/database_service.dart';
import '../utils/app_feedback.dart';

class BatchProvider extends ChangeNotifier {
  final List<Batch> _batches = [];
  bool _initialized = false;

  List<Batch> get batches => _batches;

  int get totalBirds => _batches.fold(0, (sum, b) => sum + b.currentCount);

  int get totalInitialBirds =>
      _batches.fold(0, (sum, b) => sum + b.initialCount);

  /// Loads persisted batches. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  /// Re-reads state from the database. Used at startup and to roll
  /// back optimistic in-memory updates after a failed write.
  Future<void> reload() async {
    try {
      final data = await DatabaseService.instance.getAllBatches();
      _batches
        ..clear()
        ..addAll(data.map(Batch.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint('BatchProvider: DB load failed ($e) — running in memory.');
    }
  }

  void addBatch(Batch batch) {
    _batches.add(batch);
    notifyListeners();
    _persist(() => DatabaseService.instance.insertBatch(batch.toMap()));
  }

  void deleteBatch(String id) {
    _batches.removeWhere((b) => b.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteBatch(id));
  }

  void updateBatch(Batch batch) {
    final index = _batches.indexWhere((b) => b.id == batch.id);
    if (index != -1) {
      _batches[index] = batch;
      notifyListeners();
      _persist(() => DatabaseService.instance.updateBatch(batch.toMap()));
    }
  }

  /// Adjusts a batch's live bird count by [delta] (negative = deaths).
  /// [ref] may be the batch id or its user-facing name.
  void adjustCount(String ref, int delta) {
    final index = _batches.indexWhere((b) => b.id == ref || b.name == ref);
    if (index == -1) return;
    final b = _batches[index];
    final newCount = (b.currentCount + delta).clamp(0, 1 << 30);
    final updated = b.copyWith(currentCount: newCount);
    _batches[index] = updated;
    notifyListeners();
    _persist(() => DatabaseService.instance.updateBatch(updated.toMap()));
  }

  Batch? getBatchById(String id) {
    try {
      return _batches.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Batch? getBatchByRef(String ref) {
    try {
      return _batches.firstWhere((b) => b.id == ref || b.name == ref);
    } catch (_) {
      return null;
    }
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _batches
      ..clear()
      ..addAll(data.map(Batch.fromMap));
    notifyListeners();
  }

  /// Write-through persistence: awaits the DB write and, if it
  /// fails, reloads state from the database (undoing the optimistic
  /// update) and tells the user instead of failing silently.
  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('BatchProvider: DB write failed: $e');
      showAppError(
        'Could not save — the change was not stored. Please try again.',
      );
      await reload();
    }
  }
}
