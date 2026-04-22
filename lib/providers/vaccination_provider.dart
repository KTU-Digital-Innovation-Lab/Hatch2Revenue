import 'package:flutter/foundation.dart';
import '../models/vaccination.dart';

class VaccinationProvider extends ChangeNotifier {
  final List<Vaccination> _vaccinations = [];

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

  void addVaccination(Vaccination vaccination) {
    _vaccinations.add(vaccination);
    notifyListeners();
  }

  void removeVaccination(String id) {
    _vaccinations.removeWhere((v) => v.id == id);
    notifyListeners();
  }

  void markAsCompleted(String id) {
    final index = _vaccinations.indexWhere((v) => v.id == id);
    if (index != -1) {
      _vaccinations[index] = _vaccinations[index].copyWith(
        status: VaccinationStatus.completed,
        administeredDate: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void markAsMissed(String id) {
    final index = _vaccinations.indexWhere((v) => v.id == id);
    if (index != -1) {
      _vaccinations[index] = _vaccinations[index].copyWith(
        status: VaccinationStatus.missed,
      );
      notifyListeners();
    }
  }

  void updateVaccination(Vaccination vaccination) {
    final index = _vaccinations.indexWhere((v) => v.id == vaccination.id);
    if (index != -1) {
      _vaccinations[index] = vaccination;
      notifyListeners();
    }
  }

  List<Vaccination> getVaccinationsForBatch(String batchId) {
    return _vaccinations.where((v) => v.batchId == batchId).toList();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _vaccinations.clear();
    for (var map in data) {
      _vaccinations.add(Vaccination.fromMap(map));
    }
    notifyListeners();
  }

  Future<void> loadAllVaccinations() async {
    notifyListeners();
  }
}
