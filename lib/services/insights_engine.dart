import '../providers/batch_provider.dart';
import '../providers/egg_production_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/mortality_provider.dart';
import '../providers/vaccination_provider.dart';
import '../providers/measurement_provider.dart';
import '../models/batch.dart';
import '../models/measurement.dart';
import 'flock_monitor_advice.dart';
import '../utils/units.dart';

enum InsightLevel { good, info, watch, warn, critical }

class Insight {
  final InsightLevel level;
  final String title;
  final String message;
  const Insight(this.level, this.title, this.message);
}

/// Rule-based farm insights computed from the farm's own records —
/// the same idea as FarmNest's intelligence layer, but running fully
/// offline in Dart. Guidance, never a diagnosis.
class InsightsEngine {
  // Layers eat ~110 g/bird/day; used for the feed-efficiency check.
  static const _expectedFeedGPerBird = 110;

  static List<Insight> generate({
    required BatchProvider batches,
    required EggProductionProvider eggs,
    required FeedProvider feed,
    required MortalityProvider mortality,
    required VaccinationProvider vacc,
    required MeasurementProvider measurements,
  }) {
    final out = <Insight>[];
    final birds = batches.totalBirds;

    // --- Production trend: last 7 days vs previous 7 --------------
    final totals = eggs.dailyTotals;
    if (totals.length >= 4) {
      final last7 = totals
          .skip(totals.length >= 7 ? totals.length - 7 : 0)
          .fold(0, (s, e) => s + e.value);
      final prevStart =
          totals.length >= 14 ? totals.length - 14 : 0;
      final prevEnd = totals.length >= 7 ? totals.length - 7 : 0;
      final prev7 = totals
          .skip(prevStart)
          .take(prevEnd - prevStart)
          .fold(0, (s, e) => s + e.value);
      if (prev7 > 0) {
        final change = (last7 - prev7) / prev7 * 100;
        if (change >= 3) {
          out.add(Insight(InsightLevel.good, 'Egg production up ${change.toStringAsFixed(0)}%',
              'Production rose versus the previous 7 days. Keep it up.'));
        } else if (change <= -5) {
          out.add(Insight(InsightLevel.warn, 'Egg production down ${change.abs().toStringAsFixed(0)}%',
              'Check water, feed quality, heat stress and lighting hours.'));
        }
      }
    } else if (totals.isNotEmpty) {
      out.add(const Insight(InsightLevel.info, 'Building your baseline',
          'Keep logging daily eggs — trends and forecasts sharpen after a week.'));
    }

    // --- Feed efficiency vs expected intake ----------------------
    final feedToday = feed.records
        .where((r) => _sameDay(r.date, DateTime.now()))
        .fold(0.0, (s, r) => s + r.totalKg);
    if (feedToday > 0 && birds > 0) {
      final expected = birds * _expectedFeedGPerBird / 1000;
      final dev = (feedToday - expected) / expected * 100;
      if (dev > 15) {
        out.add(Insight(InsightLevel.watch, 'Feed use ${dev.toStringAsFixed(0)}% above expected',
            'Today\'s ${Units.bagShort(feedToday)} bags vs ~${Units.bagShort(expected)} bags expected. Check for spillage or waste.'));
      } else if (dev < -20) {
        out.add(const Insight(InsightLevel.watch, 'Feed use below expected',
            'Under-feeding cuts production fast. Confirm every session was recorded.'));
      } else {
        out.add(const Insight(InsightLevel.good, 'Feed intake on target',
            'Consumption is within the expected range for your flock size.'));
      }
    }

    // --- Predicted feed requirement + stock run-out --------------
    // Forecast from flock AGE, not just past logs, so it works from day
    // one. Brooding / grower / layer birds eat about 35 / 75 / 115 g
    // per bird per day.
    if (birds > 0) {
      final fc = feedForecast(batches, feed);
      out.add(Insight(InsightLevel.info,
          '~${fc.next7Bags.toStringAsFixed(1)} bags of feed needed this week',
          'Your flock needs about ${fc.dailyKg.toStringAsFixed(0)} kg a day, '
          'roughly ${fc.next30Bags.toStringAsFixed(0)} bags over the next 30 days.'));
      if (fc.stockKg > 0 && fc.daysLeft > 0) {
        if (fc.daysLeft <= 7) {
          out.add(Insight(InsightLevel.critical,
              'Feed runs out in ~${fc.daysLeft.toStringAsFixed(0)} days',
              'At the current flock size you need feed now — deliveries take time.'));
        } else if (fc.daysLeft <= 14) {
          out.add(Insight(InsightLevel.watch,
              '~${fc.daysLeft.toStringAsFixed(0)} days of feed left',
              'Plan your next feed purchase within the week.'));
        }
      }
    }
    if (feed.stockAlertCount > 0) {
      out.add(Insight(InsightLevel.warn, '${feed.stockAlertCount} feed stock alert${feed.stockAlertCount == 1 ? "" : "s"}',
          'Some feed is low or expired — check the Feed screen.'));
    }

    // --- Mortality risk ------------------------------------------
    final weekDeaths = mortality.records
        .where((r) => r.date.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .fold(0, (s, r) => s + r.count);
    if (birds > 0 && weekDeaths > 0) {
      final pct = weekDeaths / (birds + weekDeaths) * 100;
      if (pct > 2) {
        out.add(Insight(InsightLevel.critical, 'High mortality this week',
            '$weekDeaths losses (${pct.toStringAsFixed(1)}% of the flock). Inspect the house; consider a vet.'));
      } else if (pct > 1) {
        out.add(Insight(InsightLevel.watch, 'Mortality trending up',
            '$weekDeaths losses this week — review the cause breakdown.'));
      }
    }

    // --- Vaccination compliance ----------------------------------
    if (vacc.overdueCount > 0) {
      out.add(Insight(InsightLevel.warn, '${vacc.overdueCount} overdue vaccination${vacc.overdueCount == 1 ? "" : "s"}',
          'Overdue vaccines raise disease risk. Complete them or adjust the schedule.'));
    }

    // --- Flock monitoring: weight, temperature, water ------------
    // The readings the farmer logs now drive guidance, not just charts.
    for (final b in batches.batches) {
      final checks = <(String, FlockAdvice?)>[
        ('weight', FlockMonitorAdvice.weight(
            b, measurements.series(b.id, MeasurementType.weight))),
        ('temperature', FlockMonitorAdvice.temperature(
            b, measurements.series(b.id, MeasurementType.temperature))),
        ('water intake',
            FlockMonitorAdvice.water(measurements.series(b.id, MeasurementType.water))),
      ];
      for (final (metric, advice) in checks) {
        if (advice == null || advice.level == 'good') continue;
        out.add(Insight(
          advice.level == 'warn' ? InsightLevel.warn : InsightLevel.watch,
          '${b.name}: check $metric',
          advice.message,
        ));
      }
    }

    // Positive fallback so the panel never feels empty on a healthy farm.
    if (out.isEmpty && birds > 0) {
      out.add(const Insight(InsightLevel.good, 'All looks steady',
          'No issues detected across production, feed, health and vaccines.'));
    }

    const order = {
      InsightLevel.critical: 0,
      InsightLevel.warn: 1,
      InsightLevel.watch: 2,
      InsightLevel.info: 3,
      InsightLevel.good: 4,
    };
    out.sort((a, b) => order[a.level]!.compareTo(order[b.level]!));
    return out;
  }

  /// Predicted feed requirement from flock size and age-based intake
  /// (brooding / grower / layer birds eat ~35 / 75 / 115 g per bird per
  /// day), with how long the current stock will last at that rate.
  static ({
    double dailyKg,
    double next7Bags,
    double next30Bags,
    double daysLeft,
    double stockKg,
  }) feedForecast(BatchProvider batches, FeedProvider feed) {
    double dailyG = 0;
    for (final b in batches.batches) {
      final gPerBird = switch (b.currentStage) {
        BatchStage.brooding => 35,
        BatchStage.grower => 75,
        BatchStage.layer => 115,
      };
      dailyG += b.currentCount * gPerBird;
    }
    final textbookKg = dailyG / 1000;

    // Calibrate to the farm's OWN recent consumption when we have it. The
    // age-based rate above is a textbook starting point; real intake varies
    // by breed, weather and feed. Blend the last week's actual average with
    // the textbook figure, capping a wildly out-of-range value (e.g. a bulk
    // backfill day) so the forecast tracks this farm's birds without a
    // single odd entry throwing it off.
    final recentDailyKg = feed.feedKgInLast(7) / 7;
    final double dailyKg;
    if (textbookKg > 0 && recentDailyKg > 0) {
      final capped =
          recentDailyKg.clamp(textbookKg * 0.3, textbookKg * 3.0);
      dailyKg = 0.6 * capped + 0.4 * textbookKg;
    } else {
      dailyKg = textbookKg;
    }
    const kgPerBag = 50.0;
    final stockKg = feed.totalStockKg;
    return (
      dailyKg: dailyKg,
      next7Bags: dailyKg * 7 / kgPerBag,
      next30Bags: dailyKg * 30 / kgPerBag,
      daysLeft: dailyKg > 0 ? stockKg / dailyKg : 0.0,
      stockKg: stockKg,
    );
  }

  /// 7-day egg forecast from the trailing average with a trend nudge.
  static int forecastEggs7(EggProductionProvider eggs) => eggs.forecastNext(7);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
