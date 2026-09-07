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

  /// Deaths grouped into the last [weeks] calendar weeks (Monday start),
  /// oldest first, for the mortality trend chart. Empty weeks read zero.
  List<({DateTime weekStart, int deaths})> weeklyDeaths({int weeks = 8}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final buckets = <DateTime, int>{
      for (var i = weeks - 1; i >= 0; i--)
        thisMonday.subtract(Duration(days: 7 * i)): 0,
    };
    for (final r in _records) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      final monday = d.subtract(Duration(days: d.weekday - 1));
      if (buckets.containsKey(monday)) {
        buckets[monday] = buckets[monday]! + r.count;
      }
    }
    final keys = buckets.keys.toList()..sort();
    return [for (final k in keys) (weekStart: k, deaths: buckets[k]!)];
  }

  /// A plain-language disease-threat read from recent deaths, or null
  /// when nothing stands out. It looks for a spike (this week well above
  /// the recent weekly average) and for a cause cluster (one cause
  /// dominating the last fortnight) — either can be an early sign of a
  /// disease problem.
  ({String title, String detail})? diseaseThreat() {
    final weekly = weeklyDeaths(weeks: 6);
    if (weekly.length < 2) return null;
    final thisWeek = weekly.last.deaths;
    final prior = weekly.sublist(0, weekly.length - 1).map((w) => w.deaths).toList();
    final avgPrior = prior.reduce((a, b) => a + b) / prior.length;
    final spike = thisWeek >= 4 &&
        (avgPrior <= 0 ? thisWeek >= 6 : thisWeek > avgPrior * 2);

    // Cause cluster over the last 14 days.
    final since = DateTime.now().subtract(const Duration(days: 14));
    final recent = _records.where((r) => !r.date.isBefore(since));
    final recentTotal = recent.fold(0, (s, r) => s + r.count);
    final byCause = <MortalityCause, int>{};
    for (final r in recent) {
      final c = r.cause ?? MortalityCause.unknown;
      byCause[c] = (byCause[c] ?? 0) + r.count;
    }
    MortalityCause? topCause;
    var topCount = 0;
    byCause.forEach((c, n) {
      if (n > topCount) { topCount = n; topCause = c; }
    });
    final clusterCauses = {
      MortalityCause.disease, MortalityCause.heatStress, MortalityCause.cold,
    };
    final cluster = recentTotal >= 5 &&
        topCause != null &&
        clusterCauses.contains(topCause) &&
        topCount / recentTotal >= 0.6;

    if (cluster) {
      final name = Mortality(batchId: '', date: DateTime.now(), count: 0, cause: topCause)
          .causeName;
      return (
        title: 'Possible disease threat',
        detail: '$topCount of the last $recentTotal deaths are from $name. '
            'A cluster on one cause can signal an outbreak, so check the birds '
            'closely and consider calling a vet.',
      );
    }
    if (spike) {
      return (
        title: 'Deaths are rising sharply',
        detail: "This week's deaths ($thisWeek) are well above the recent "
            'weekly average (${avgPrior.toStringAsFixed(0)}). A sudden rise can '
            'be an early disease sign. Check water, feed, ventilation and the flock.',
      );
    }
    return null;
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
