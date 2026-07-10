import 'package:flutter/foundation.dart';
import '../models/vaccination.dart';
import '../services/database_service.dart';
import '../utils/app_feedback.dart';

class VaccinationProvider extends ChangeNotifier {
  final List<Vaccination> _vaccinations = [];
  bool _initialized = false;

  List<Vaccination> get vaccinations => _vaccinations;

  int get scheduledCount => _vaccinations
      .where((v) => v.status == VaccinationStatus.scheduled)
      .length;

  int get completedCount => _vaccinations
      .where((v) => v.status == VaccinationStatus.completed)
      .length;

  int get overdueCount => _vaccinations.where((v) => v.isOverdue).length;

  List<Vaccination> get upcomingVaccinations {
    final now = DateTime.now();
    return _vaccinations
        .where(
          (v) =>
              v.status == VaccinationStatus.scheduled &&
              v.scheduledDate.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
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
      final data = await DatabaseService.instance.getAllVaccinations();
      _vaccinations
        ..clear()
        ..addAll(data.map(Vaccination.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint(
        'VaccinationProvider: DB load failed ($e) — running in memory.',
      );
    }
  }

  void addVaccination(Vaccination vaccination) {
    _vaccinations.add(vaccination);
    notifyListeners();
    _persist(
      () => DatabaseService.instance.insertVaccination(vaccination.toMap()),
    );
  }

  /// Bulk-add (used by auto-generated schedules) — one notify at the end.
  void addAll(List<Vaccination> vaccinations) {
    _vaccinations.addAll(vaccinations);
    notifyListeners();
    for (final v in vaccinations) {
      _persist(() => DatabaseService.instance.insertVaccination(v.toMap()));
    }
  }

  void removeVaccination(String id) {
    _vaccinations.removeWhere((v) => v.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteVaccination(id));
  }

  /// Removes all vaccinations belonging to a deleted batch.
  /// [refs] should contain the batch id and its name.
  void removeByBatchRefs(Set<String> refs) {
    final doomed =
        _vaccinations.where((v) => refs.contains(v.batchId)).toList();
    if (doomed.isEmpty) return;
    _vaccinations.removeWhere((v) => refs.contains(v.batchId));
    notifyListeners();
    for (final v in doomed) {
      _persist(() => DatabaseService.instance.deleteVaccination(v.id));
    }
  }

  void markAsCompleted(String id) {
    final index = _vaccinations.indexWhere((v) => v.id == id);
    if (index != -1) {
      final updated = _vaccinations[index].copyWith(
        status: VaccinationStatus.completed,
        administeredDate: DateTime.now(),
      );
      _vaccinations[index] = updated;
      notifyListeners();
      _persist(
        () => DatabaseService.instance.updateVaccination(updated.toMap()),
      );
    }
  }

  void markAsMissed(String id) {
    final index = _vaccinations.indexWhere((v) => v.id == id);
    if (index != -1) {
      final updated = _vaccinations[index].copyWith(
        status: VaccinationStatus.missed,
      );
      _vaccinations[index] = updated;
      notifyListeners();
      _persist(
        () => DatabaseService.instance.updateVaccination(updated.toMap()),
      );
    }
  }

  void updateVaccination(Vaccination vaccination) {
    final index = _vaccinations.indexWhere((v) => v.id == vaccination.id);
    if (index != -1) {
      _vaccinations[index] = vaccination;
      notifyListeners();
      _persist(
        () => DatabaseService.instance.updateVaccination(vaccination.toMap()),
      );
    }
  }

  List<Vaccination> getVaccinationsForBatch(String batchId) {
    return _vaccinations.where((v) => v.batchId == batchId).toList();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _vaccinations
      ..clear()
      ..addAll(data.map(Vaccination.fromMap));
    notifyListeners();
  }

  /// Write-through persistence: awaits the DB write and, if it
  /// fails, reloads state from the database (undoing the optimistic
  /// update) and tells the user instead of failing silently.
  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('VaccinationProvider: DB write failed: $e');
      showAppError(
        'Could not save — the change was not stored. Please try again.',
      );
      await reload();
    }
  }
}
