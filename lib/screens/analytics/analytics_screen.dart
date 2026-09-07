import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/financial_provider.dart';
import '../../providers/mortality_provider.dart';
import '../../providers/batch_provider.dart';
import '../../models/mortality.dart';
import '../../services/insights_engine.dart';
import '../../utils/app_colors.dart';
import '../../utils/caps.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/html_widgets.dart';
import '../../utils/units.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caps = Caps.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: AppColors.amber, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analytics', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Performance, productivity and forecasts', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSummaryRow(context),
          const SizedBox(height: 16),
          // Efficiency + productivity KPIs (merged in from the old
          // separate Productivity screen).
          _buildEfficiencyGrid(context),
          const SizedBox(height: 16),
          _buildInterpretCard(context),
          const SizedBox(height: 16),
          _ChartCard(title: '7-Day Egg Forecast', icon: Icons.online_prediction, child: _ForecastCard()),
          const SizedBox(height: 16),
          _ChartCard(title: 'Egg Production — Crates (Last 10)', icon: Icons.egg_outlined, child: _EggProductionChart()),
          // Money views only for roles allowed to see money (owner/manager).
          if (caps.canSeeMoney) ...[
            const SizedBox(height: 16),
            _ChartCard(title: 'Financial Breakdown', icon: Icons.account_balance_wallet_outlined, child: _FinancialBars()),
          ],
          const SizedBox(height: 16),
          _ChartCard(title: 'Mortality by Cause', icon: Icons.warning_amber_rounded, child: _MortalityBars()),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context) {
    final caps = Caps.of(context);
    final batches = context.watch<BatchProvider>().batches;
    final eggs = context.watch<EggProductionProvider>();
    final fin = context.watch<FinancialProvider>();

    return Row(
      children: [
        Expanded(child: _MiniStat(label: 'BATCHES', value: '${batches.length}', color: AppColors.amber)),
        const SizedBox(width: 10),
        Expanded(child: _MiniStat(label: 'TOTAL CRATES', value: Units.crateShort(eggs.totalEggs), color: AppColors.green)),
        if (caps.canSeeMoney) ...[
          const SizedBox(width: 10),
          Expanded(child: _MiniStat(label: 'NET PROFIT', value: '${CurrencyFormatter.currencySymbol}${fin.netProfit.toStringAsFixed(0)}', color: fin.netProfit >= 0 ? AppColors.cyan : AppColors.red)),
        ],
      ],
    );
  }

  /// Efficiency + productivity KPIs — how well the flock turns feed and
  /// birds into eggs, plus unit costs. Unit-cost cards are money-gated.
  Widget _buildEfficiencyGrid(BuildContext context) {
    final caps = Caps.of(context);
    final batch = context.watch<BatchProvider>();
    final eggs = context.watch<EggProductionProvider>();
    final feed = context.watch<FeedProvider>();
    final fin = context.watch<FinancialProvider>();

    final birds = batch.totalBirds;
    final initial = batch.totalInitialBirds;
    final eggs7 = eggs.eggsInLast(7);
    final layingRate = birds > 0 ? eggs7 / (birds * 7) * 100 : 0.0;
    final survival = initial > 0 ? birds / initial * 100 : 0.0;
    final eggMassKg = eggs.totalEggs * 0.06;
    final fcr = eggMassKg > 0 ? feed.totalFeedKg / eggMassKg : 0.0;
    final eggsPerBird = initial > 0 ? eggs.totalEggs / initial : 0.0;
    final crates = Units.eggsToCrates(eggs.totalEggs);
    final costPerBird = birds > 0 ? fin.totalExpenses / birds : 0.0;
    final costPerEgg = eggs.totalEggs > 0 ? fin.totalExpenses / eggs.totalEggs : 0.0;
    final fc = InsightsEngine.feedForecast(batch, feed);
    final feedPerBirdG = birds > 0 ? fc.dailyKg * 1000 / birds : 0.0;
    final sym = CurrencyFormatter.currencySymbol;

    return KpiGrid(children: [
      KpiCard(
        // Over 100% is not a great laying rate, it is a bad entry: a hen
        // lays at most one egg a day. Flag it instead of showing green.
        label: 'Hen-day 7d',
        value: birds > 0
            ? '${layingRate.toStringAsFixed(1)}%${layingRate > 100.5 ? ' (check)' : ''}'
            : '—',
        sub: 'eggs per hen per day',
        accentColor: layingRate > 100.5
            ? AppColors.red
            : layingRate >= 70
                ? AppColors.green
                : layingRate >= 50
                    ? AppColors.amber
                    : AppColors.red,
      ),
      KpiCard(
        label: 'Survival',
        value: initial > 0
            ? '${survival.toStringAsFixed(1)}%${survival > 100.5 ? ' (check)' : ''}'
            : '—',
        sub: '$birds of $initial birds',
        accentColor: survival > 100.5
            ? AppColors.red
            : survival >= 95
                ? AppColors.green
                : survival >= 90
                    ? AppColors.amber
                    : AppColors.red,
      ),
      KpiCard(
        label: 'FCR',
        value: fcr > 0 ? fcr.toStringAsFixed(2) : '—',
        sub: 'feed per egg, lower better',
        accentColor: fcr > 0 && fcr < 2.3 ? AppColors.green : AppColors.amber,
      ),
      KpiCard(
        label: 'Eggs per bird',
        value: eggsPerBird > 0 ? eggsPerBird.toStringAsFixed(0) : '—',
        sub: 'to date',
        accentColor: AppColors.cyan,
      ),
      KpiCard(
        label: 'Crates produced',
        value: crates > 0 ? crates.toStringAsFixed(0) : '—',
        accentColor: AppColors.amber,
      ),
      KpiCard(
        label: 'Feed/bird·day',
        value: feedPerBirdG > 0 ? '${feedPerBirdG.toStringAsFixed(0)} g' : '—',
        accentColor: AppColors.blue,
      ),
      if (caps.canSeeMoney) ...[
        KpiCard(
          label: 'Cost per bird',
          value: costPerBird > 0 ? '$sym${costPerBird.toStringAsFixed(2)}' : '—',
          accentColor: AppColors.purple,
        ),
        KpiCard(
          label: 'Cost per egg',
          value: costPerEgg > 0 ? '$sym${costPerEgg.toStringAsFixed(2)}' : '—',
          accentColor: AppColors.purple,
        ),
      ],
    ]);
  }

  Widget _buildInterpretCard(BuildContext context) {
    final batch = context.watch<BatchProvider>();
    final eggs = context.watch<EggProductionProvider>();
    final feed = context.watch<FeedProvider>();

    final birds = batch.totalBirds;
    final initial = batch.totalInitialBirds;
    final eggs7 = eggs.eggsInLast(7);
    final layingRate = birds > 0 ? eggs7 / (birds * 7) * 100 : 0.0;
    final survival = initial > 0 ? birds / initial * 100 : 0.0;
    final eggMassKg = eggs.totalEggs * 0.06;
    final fcr = eggMassKg > 0 ? feed.totalFeedKg / eggMassKg : 0.0;

    return HtmlCard(
      header: const HtmlCardHeader(
          icon: Icons.lightbulb_outline, title: 'What this means'),
      body: Text(
        _interpret(layingRate, survival, fcr, birds),
        style: TextStyle(
            color: AppColors.textSecondary, fontSize: 13, height: 1.5),
      ),
    );
  }

  String _interpret(double laying, double survival, double fcr, int birds) {
    if (birds == 0) {
      return 'Add a flock and log eggs, feed and deaths to see your '
          'productivity metrics here.';
    }
    final parts = <String>[];
    parts.add(laying >= 70
        ? 'Laying rate is strong at ${laying.toStringAsFixed(0)}% — a healthy layer flock.'
        : laying >= 50
            ? 'Laying rate of ${laying.toStringAsFixed(0)}% has room to improve; check lighting hours, feed and water.'
            : 'Laying rate of ${laying.toStringAsFixed(0)}% is low; review feed quality, disease and flock age.');
    parts.add(survival >= 95
        ? 'Survival of ${survival.toStringAsFixed(0)}% is excellent.'
        : 'Survival of ${survival.toStringAsFixed(0)}% — keep a close eye on mortality.');
    if (fcr > 0) {
      parts.add(fcr < 2.3
          ? 'Feed conversion of ${fcr.toStringAsFixed(2)} is efficient.'
          : 'Feed conversion of ${fcr.toStringAsFixed(2)} is high; reduce waste and confirm intake.');
    }
    return parts.join(' ');
  }
}

class _ForecastCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final eggs = context.watch<EggProductionProvider>();
    if (eggs.records.isEmpty) {
      return const _EmptyChart(message: 'Log egg production to see forecasts');
    }
    final next7 = eggs.forecastNext(7);
    final last7 = eggs.eggsInLast(7);
    final perDay = next7 / 7;
    final trendUp = next7 >= last7;

    return Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROJECTED NEXT 7 DAYS', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 9, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text('${Units.crateShort(next7)} crates', style: GoogleFonts.poppins(color: AppColors.amber, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('≈ ${Units.crateShort(perDay.round())} crates/day · linear trend on recent logs', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10)),
        ],
      )),
      Column(children: [
        Icon(trendUp ? Icons.trending_up : Icons.trending_down, color: trendUp ? AppColors.green : AppColors.red, size: 30),
        const SizedBox(height: 4),
        Text(
          last7 > 0 ? '${(next7 / last7 * 100 - 100).toStringAsFixed(0)}% vs last 7d' : 'no baseline',
          style: GoogleFonts.inter(color: trendUp ? AppColors.green : AppColors.red, fontSize: 10),
        ),
      ]),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    // Accent bar overlays a plain rounded card; the ClipRRect trims its
    // ends to the card's corner radius so the two blend seamlessly.
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 13, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 9, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 3, color: color),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _ChartCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.amber, size: 18),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EggProductionChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final records = context.watch<EggProductionProvider>().records;
    if (records.isEmpty) return const _EmptyChart(message: 'No egg production data yet');

    final last10 = records.length > 10 ? records.sublist(records.length - 10) : records;
    final maxY = last10.map((r) => Units.eggsToCrates(r.eggCount)).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxY * 1.3).ceilToDouble(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceLight,
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${Units.crateShort(last10[group.x].eggCount)} crates',
                TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= last10.length) return const SizedBox.shrink();
                  final d = last10[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${d.day}/${d.month}', style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          barGroups: last10.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(
              toY: Units.eggsToCrates(e.value.eggCount),
              color: AppColors.amber,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            )],
          )).toList(),
        ),
      ),
    );
  }
}

// Income vs expenses read better as two horizontal bars than as a pie:
// the question is "how much bigger is one than the other", which a bar
// answers at a glance and a pie does not.
class _FinancialBars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinancialProvider>();
    if (fin.transactions.isEmpty) return const _EmptyChart(message: 'No financial data yet');
    final income = fin.totalIncome;
    final expenses = fin.totalExpenses;
    if (income == 0 && expenses == 0) return const _EmptyChart(message: 'No financial data yet');
    final max = income > expenses ? income : expenses;
    final sym = CurrencyFormatter.currencySymbol;

    return Column(
      children: [
        _HBar(label: 'Income', valueLabel: '$sym${income.toStringAsFixed(0)}', fraction: max > 0 ? income / max : 0, color: AppColors.green),
        _HBar(label: 'Expenses', valueLabel: '$sym${expenses.toStringAsFixed(0)}', fraction: max > 0 ? expenses / max : 0, color: AppColors.red),
        // Net profit is derived, not a bar. Amber (not expense-red) when
        // negative so it cannot be confused with Expenses.
        Row(children: [
          Expanded(child: Text(fin.netProfit >= 0 ? 'Net profit' : 'Net loss', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
          Text(
            '${fin.netProfit < 0 ? '-' : ''}$sym${fin.netProfit.abs().toStringAsFixed(0)}',
            style: TextStyle(color: fin.netProfit >= 0 ? AppColors.cyan : AppColors.amber, fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ]),
      ],
    );
  }
}

/// A labelled horizontal bar: label and value on top, a proportional fill
/// below. Replaces the pie legends across the analytics charts.
class _HBar extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double fraction;
  final Color color;
  const _HBar({required this.label, required this.valueLabel, required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
            const SizedBox(width: 8),
            Text(valueLabel, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// Deaths by cause as ranked horizontal bars (largest first), so the
// dominant cause is obvious. A pie hid that behind similar-looking slices.
class _MortalityBars extends StatelessWidget {
  Map<MortalityCause, Color> get _colors => {
        MortalityCause.disease: AppColors.red,
        MortalityCause.predator: AppColors.purple,
        MortalityCause.heatStress: AppColors.amber,
        MortalityCause.cold: AppColors.cyan,
        MortalityCause.suffocation: AppColors.blue,
        MortalityCause.unknown: AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final records = context.watch<MortalityProvider>().records;
    if (records.isEmpty) return const _EmptyChart(message: 'No mortality data yet');

    final byCause = <MortalityCause, int>{};
    for (final r in records) {
      final cause = r.cause ?? MortalityCause.unknown;
      byCause[cause] = (byCause[cause] ?? 0) + r.count;
    }
    final entries = byCause.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 0 : entries.first.value;

    return Column(
      children: entries
          .map((e) => _HBar(
                label: e.key.name[0].toUpperCase() + e.key.name.substring(1),
                valueLabel: '${e.value}',
                fraction: max > 0 ? e.value / max : 0,
                color: _colors[e.key] ?? AppColors.textMuted,
              ))
          .toList(),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 28, color: AppColors.textMuted),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      )),
    );
  }
}
    