import 'package:flutter/foundation.dart';
import '../models/egg_production.dart';
import '../services/database_service.dart';
import '../utils/app_feedback.dart';

class EggProductionProvider extends ChangeNotifier {
  final List<EggProduction> _records = [];
  bool _initialized = false;

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

  /// Average eggs per *calendar day* with data (not per record).
  double get averagePerDay {
    if (_records.isEmpty) return 0.0;
    final days = _records
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .length;
    return days == 0 ? 0.0 : totalEggs / days;
  }

  /// Eggs collected in the last [days] days.
  int eggsInLast(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _records
        .where((e) => e.date.isAfter(cutoff))
        .fold(0, (sum, e) => sum + e.eggCount);
  }

  /// Daily totals sorted by day (for charts/forecasting).
  List<MapEntry<DateTime, int>> get dailyTotals {
    final map = <DateTime, int>{};
    for (final e in _records) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      map[day] = (map[day] ?? 0) + e.eggCount;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  /// Linear-trend forecast of total eggs over the next [days] days,
  /// fitted on the daily totals of the last 14 calendar days.
  ///
  /// The fit runs against elapsed days, not the position of a record in
  /// the list. A farmer who misses a day leaves a gap in [dailyTotals],
  /// and treating those entries as evenly spaced would distort the
  /// slope — a real risk here, because irregular logging is normal on a
  /// working farm. Falls back to the recent daily average when there is
  /// too little data to fit a trend.
  int forecastNext(int days) {
    final totals = dailyTotals;
    if (totals.isEmpty) return 0;

    // Window by calendar date rather than record count, so 14 sparse
    // entries spread over two months are not treated as a fortnight.
    final lastDay = totals.last.key;
    final windowStart = lastDay.subtract(const Duration(days: 13));
    final recent =
        totals.where((e) => !e.key.isBefore(windowStart)).toList();
    final n = recent.length;

    // Days elapsed since the first day in the window: 0, 1, 4, 5...
    final firstDay = recent.first.key;
    final xs = recent
        .map((e) => e.key.difference(firstDay).inDays.toDouble())
        .toList();
    final ys = recent.map((e) => e.value.toDouble()).toList();

    if (n < 3) {
      final avg = recent.fold(0, (s, e) => s + e.value) / n;
      return (avg * days).round();
    }

    // Least-squares fit: y = a + b*x
    final xMean = xs.reduce((a, b) => a + b) / n;
    final yMean = ys.reduce((a, b) => a + b) / n;
    double num = 0, den = 0;
    for (var i = 0; i < n; i++) {
      num += (xs[i] - xMean) * (ys[i] - yMean);
      den += (xs[i] - xMean) * (xs[i] - xMean);
    }
    final b = den == 0 ? 0.0 : num / den;
    final a = yMean - b * xMean;

    // Project forward from the last day actually logged.
    final lastX = xs.last;
    double sum = 0;
    for (var d = 1; d <= days; d++) {
      final projected = a + b * (lastX + d);
      sum += projected < 0 ? 0 : projected;
    }
    return sum.round();
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
      final data = await DatabaseService.instance.getAllEggProduction();
      _records
        ..clear()
        ..addAll(data.map(EggProduction.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint(
        'EggProductionProvider: DB load failed ($e) — running in memory.',
      );
    }
  }

  void addRecord(EggProduction record) {
    _records.add(record);
    notifyListeners();
    _persist(
      () => DatabaseService.instance.insertEggProduction(record.toMap()),
    );
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteEggProduction(id));
  }

  void removeByBatchRefs(Set<String> refs) {
    final doomed = _records.where((r) => refs.contains(r.batchId)).toList();
    if (doomed.isEmpty) return;
    _records.removeWhere((r) => refs.contains(r.batchId));
    notifyListeners();
    for (final r in doomed) {
      _persist(() => DatabaseService.instance.deleteEggProduction(r.id));
    }
  }

  void updateRecord(EggProduction record) {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
      notifyListeners();
      _persist(
        () => DatabaseService.instance.updateEggProduction(record.toMap()),
      );
    }
  }

  List<EggProduction> getRecordsForBatch(String batchId) {
    return _records.where((r) => r.batchId == batchId).toList();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _records
      ..clear()
      ..addAll(data.map(EggProduction.fromMap));
    notifyListeners();
  }

  /// Write-through persistence: awaits the DB write and, if it
  /// fails, reloads state from the database (undoing the optimistic
  /// update) and tells the user instead of failing silently.
  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('EggProductionProvider: DB write failed: $e');
      showAppError(
        'Could not save — the change was not stored. Please try again.',
      );
      await reload();
    }
  }
}
