import 'package:flutter/foundation.dart';
import '../models/batch.dart';

class BatchProvider extends ChangeNotifier {
  final List<Batch> _batches = [];

  List<Batch> get batches => _batches;

  int get totalBirds => _batches.fold(0, (sum, b) => sum + b.currentCount);

  void addBatch(Batch batch) {
    _batches.add(batch);
    notifyListeners();
  }

  void deleteBatch(String id) {
    _batches.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  void updateBatch(Batch batch) {
    final index = _batches.indexWhere((b) => b.id == batch.id);
    if (index != -1) {
      _batches[index] = batch;
      notifyListeners();
    }
  }

  Batch? getBatchById(String id) {
    try {
      return _batches.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _batches.clear();
    for (var map in data) {
      _batches.add(Batch.fromMap(map));
    }
    notifyListeners();
  }

  Future<void> loadAllBatches() async {
    notifyListeners();
  }
}
