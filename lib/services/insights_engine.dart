import '../providers/batch_provider.dart';
import '../providers/egg_production_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/mortality_provider.dart';
import '../providers/vaccination_provider.dart';

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
            'Today\'s ${feedToday.toStringAsFixed(0)} kg vs ~${expected.toStringAsFixed(0)} kg expected. Check for spillage or waste.'));
      } else if (dev < -20) {
        out.add(const Insight(InsightLevel.watch, 'Feed use below expected',
            'Under-feeding cuts production fast. Confirm every session was recorded.'));
      } else {
        out.add(const Insight(InsightLevel.good, 'Feed intake on target',
            'Consumption is within the expected range for your flock size.'));
      }
    }

    // --- Feed stock run-out --------------------------------------
    final stock = feed.totalStockKg;
    final avgDaily = feed.records.isEmpty
        ? 0.0
        : feed.totalFeedConsumed / feed.records.length;
    if (stock > 0 && avgDaily > 0) {
      final days = stock / avgDaily;
      if (days <= 7) {
        out.add(Insight(InsightLevel.critical, 'Feed runs out in ~${days.toStringAsFixed(0)} days',
            'Order feed now — deliveries take time.'));
      } else if (days <= 14) {
        out.add(Insight(InsightLevel.watch, '~${days.toStringAsFixed(0)} days of feed left',
            'Plan your next purchase within the week.'));
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

  /// 7-day egg forecast from the trailing average with a trend nudge.
  static int forecastEggs7(EggProductionProvider eggs) => eggs.forecastNext(7);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
