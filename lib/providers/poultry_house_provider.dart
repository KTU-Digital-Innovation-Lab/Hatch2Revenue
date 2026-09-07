import 'package:flutter/foundation.dart';
import '../models/poultry_house.dart';
import '../services/database_service.dart';
import '../utils/app_feedback.dart';

/// Poultry houses / coops. Flocks link to a house via Batch.coopId.
class PoultryHouseProvider extends ChangeNotifier {
  final List<PoultryHouse> _houses = [];
  bool _initialized = false;

  List<PoultryHouse> get houses => _houses;

  PoultryHouse? byId(String? id) {
    if (id == null) return null;
    for (final h in _houses) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  Future<void> reload() async {
    try {
      final data = await DatabaseService.instance.getAllPoultryHouses();
      _houses
        ..clear()
        ..addAll(data.map(PoultryHouse.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint('PoultryHouseProvider: DB load failed ($e) — running in memory.');
    }
  }

  void addHouse(PoultryHouse h) {
    _houses.add(h);
    notifyListeners();
    _persist(() => DatabaseService.instance.insertPoultryHouse(h.toMap()));
  }

  void updateHouse(PoultryHouse h) {
    final i = _houses.indexWhere((x) => x.id == h.id);
    if (i != -1) {
      _houses[i] = h;
      notifyListeners();
      _persist(() => DatabaseService.instance.updatePoultryHouse(h.toMap()));
    }
  }

  void removeHouse(String id) {
    _houses.removeWhere((x) => x.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deletePoultryHouse(id));
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _houses
      ..clear()
      ..addAll(data.map(PoultryHouse.fromMap));
    notifyListeners();
  }

  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('PoultryHouseProvider: DB write failed: $e');
      showAppError('Could not save — the change was not stored. Please try again.');
      await reload();
    }
  }
}
