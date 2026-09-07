import '../models/batch.dart';
import '../models/measurement.dart';

/// A plain-language reading of one monitoring metric.
class FlockAdvice {
  /// 'good' | 'watch' | 'warn'
  final String level;
  final String message;
  const FlockAdvice(this.level, this.message);
}

/// Turns raw flock readings (weight, temperature, water) into guidance.
/// Shared by the monitoring screen (per metric) and the dashboard
/// intelligence panel (warnings across flocks).
class FlockMonitorAdvice {
  // Standard brown-layer pullet body weight (grams) by age in weeks —
  // control points from typical growth guides, linearly interpolated.
  static const List<(double, double)> _weightCurve = [
    (0, 40), (1, 70), (2, 120), (3, 190), (4, 300), (6, 480), (8, 700),
    (10, 900), (12, 1080), (14, 1250), (16, 1400), (18, 1500), (20, 1650),
    (24, 1800), (30, 1900),
  ];

  static double targetWeightG(double weeks) {
    if (weeks <= _weightCurve.first.$1) return _weightCurve.first.$2;
    if (weeks >= _weightCurve.last.$1) return _weightCurve.last.$2;
    for (var i = 0; i < _weightCurve.length - 1; i++) {
      final a = _weightCurve[i], b = _weightCurve[i + 1];
      if (weeks >= a.$1 && weeks <= b.$1) {
        final t = (weeks - a.$1) / (b.$1 - a.$1);
        return a.$2 + (b.$2 - a.$2) * t;
      }
    }
    return _weightCurve.last.$2;
  }

  static String _g(double v) => v.toStringAsFixed(0);

  /// Weight vs the breed-standard target for the flock's age, plus a
  /// readiness note near point of lay. [series] is oldest-first (grams).
  static FlockAdvice? weight(Batch b, List<Measurement> series) {
    if (series.isEmpty) return null;
    final weeks = b.ageInDays / 7;
    final latest = series.last.value;
    final target = targetWeightG(weeks);
    final ratio = target > 0 ? latest / target : 1.0;
    if (ratio < 0.90) {
      return FlockAdvice('warn',
          'Average weight ${_g(latest)} g is below the ~${_g(target)} g expected '
          'at ${weeks.toStringAsFixed(0)} weeks. Underweight birds come into lay '
          'late and lay less — check feed amount, feed quality and health.');
    }
    if (ratio > 1.15) {
      return FlockAdvice('watch',
          'Average weight ${_g(latest)} g is above the ~${_g(target)} g target. '
          'Over-conditioning wastes feed and can hurt laying — review feed portions.');
    }
    if (series.length >= 2 && b.currentStage != BatchStage.layer) {
      final prev = series[series.length - 2];
      final days = series.last.date.difference(prev.date).inDays.abs();
      if (days >= 3 && latest <= prev.value) {
        return FlockAdvice('watch',
            'Weight has stopped rising since the last reading — a stall can point '
            'to a feed or health problem. Check intake and the birds.');
      }
    }
    if (weeks >= 16 && weeks < 20 && latest >= 1350) {
      return const FlockAdvice('good',
          'Weight is on target and near point-of-lay readiness (~1.4-1.5 kg).');
    }
    return FlockAdvice('good',
        'Weight is on target for ${weeks.toStringAsFixed(0)} weeks.');
  }

  /// House temperature vs the comfortable range for the flock's stage.
  static FlockAdvice? temperature(Batch b, List<Measurement> series) {
    if (series.isEmpty) return null;
    final latest = series.last.value;
    double low, high;
    if (b.currentStage == BatchStage.brooding) {
      final wk = b.ageInDays / 7;
      high = (35 - (wk - 1) * 2.5).clamp(24.0, 35.0);
      low = high - 3;
    } else {
      low = 18;
      high = 26;
    }
    final range = '${low.toStringAsFixed(0)}-${high.toStringAsFixed(0)}°C';
    if (latest > high) {
      return FlockAdvice('warn',
          'House temperature ${latest.toStringAsFixed(0)}°C is above the ideal '
          '($range) for this stage. Heat stress cuts laying and raises deaths — '
          'give cool water, shade and better airflow.');
    }
    if (latest < low) {
      final chicks =
          b.currentStage == BatchStage.brooding ? ' Chicks especially need heat.' : '';
      return FlockAdvice('watch',
          'House temperature ${latest.toStringAsFixed(0)}°C is below the ideal '
          '($range).$chicks Reduce draughts and add warmth.');
    }
    return FlockAdvice('good',
        'Temperature is in the comfortable range ($range) for this stage.');
  }

  /// Water intake trend. A sudden drop is one of the earliest signs of a
  /// health problem — birds go off water before feed and before other
  /// symptoms show. [series] is oldest-first (litres).
  static FlockAdvice? water(List<Measurement> series) {
    if (series.length < 4) return null;
    final latest = series.last.value;
    final prior = series.sublist(0, series.length - 1);
    final recent = prior.length > 7 ? prior.sublist(prior.length - 7) : prior;
    final avg = recent.map((m) => m.value).reduce((a, b) => a + b) / recent.length;
    if (avg <= 0) return null;
    final drop = (avg - latest) / avg;
    if (drop >= 0.30) {
      return FlockAdvice('warn',
          'Water intake is ${(drop * 100).round()}% below the recent average. '
          'Birds often go off water before any other sign of illness — check the '
          'flock, the water lines, and for heat or disease.');
    }
    if (drop >= 0.15) {
      return FlockAdvice('watch',
          'Water intake is down ${(drop * 100).round()}% on the recent average — '
          'worth checking the water supply and the birds.');
    }
    return const FlockAdvice('good', 'Water intake is steady.');
  }
}
