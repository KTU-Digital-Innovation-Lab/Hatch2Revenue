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
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/units.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: AppColors.amber, size: 30),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Visualize your farm performance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSummaryRow(context),
          const SizedBox(height: 16),
          _buildKpiGrid(context),
          const SizedBox(height: 16),
          _ChartCard(title: '7-Day Egg Forecast', icon: Icons.online_prediction, child: _ForecastCard()),
          const SizedBox(height: 16),
          _ChartCard(title: 'Egg Production — Crates (Last 10)', icon: Icons.egg_outlined, child: _EggProductionChart()),
          const SizedBox(height: 16),
          _ChartCard(title: 'Financial Breakdown', icon: Icons.account_balance_wallet_outlined, child: _FinancialPieChart()),
          const SizedBox(height: 16),
          _ChartCard(title: 'Mortality by Cause', icon: Icons.warning_amber_rounded, child: _MortalityPieChart()),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context) {
    final batches = context.watch<BatchProvider>().batches;
    final eggs = context.watch<EggProductionProvider>();
    final fin = context.watch<FinancialProvider>();

    return Row(
      children: [
        Expanded(child: _MiniStat(label: 'BATCHES', value: '${batches.length}', color: AppColors.amber)),
        const SizedBox(width: 10),
        Expanded(child: _MiniStat(label: 'TOTAL CRATES', value: Units.crateShort(eggs.totalEggs), color: AppColors.green)),
        const SizedBox(width: 10),
        Expanded(child: _MiniStat(label: 'NET PROFIT', value: '${CurrencyFormatter.currencySymbol}${fin.netProfit.toStringAsFixed(0)}', color: fin.netProfit >= 0 ? AppColors.cyan : AppColors.red)),
      ],
    );
  }

  /// Farm-performance KPIs: laying rate, mortality rate, FCR, cost per crate.
  Widget _buildKpiGrid(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final eggs = context.watch<EggProductionProvider>();
    final feed = context.watch<FeedProvider>();
    final mortality = context.watch<MortalityProvider>();

    // Laying rate: eggs over the last 7 days vs. hen-days available.
    final birds = batchProvider.totalBirds;
    final eggs7 = eggs.eggsInLast(7);
    final layingRate = birds > 0 ? (eggs7 / (birds * 7)) * 100 : 0.0;

    // Cumulative mortality vs. birds ever housed.
    final initialBirds = batchProvider.totalInitialBirds;
    final mortalityRate =
        initialBirds > 0 ? mortality.totalCount / initialBirds * 100 : 0.0;

    // FCR: kg of feed per kg of egg mass (avg egg ≈ 60 g).
    final eggMassKg = eggs.totalEggs * 0.06;
    final fcr = eggMassKg > 0 ? feed.totalFeedKg / eggMassKg : 0.0;

    // Feed cost per crate produced.
    final costPerCrate = eggs.totalEggs > 0
        ? feed.totalFeedCost / Units.eggsToCrates(eggs.totalEggs)
        : 0.0;

    return Column(children: [
      Row(children: [
        Expanded(child: _MiniStat(
          label: 'LAYING RATE (7D)',
          value: birds > 0 ? '${layingRate.toStringAsFixed(1)}%' : '—',
          color: layingRate >= 70 ? AppColors.green : layingRate >= 50 ? AppColors.amber : AppColors.red,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MiniStat(
          label: 'MORTALITY RATE',
          value: initialBirds > 0 ? '${mortalityRate.toStringAsFixed(1)}%' : '—',
          color: mortalityRate <= 5 ? AppColors.green : mortalityRate <= 10 ? AppColors.amber : AppColors.red,
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MiniStat(
          label: 'FCR (FEED/EGG KG)',
          value: fcr > 0 ? fcr.toStringAsFixed(2) : '—',
          color: fcr > 0 && fcr < 2.3 ? AppColors.green : AppColors.amber,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MiniStat(
          label: 'FEED COST / CRATE',
          value: costPerCrate > 0 ? '${CurrencyFormatter.currencySymbol}${costPerCrate.toStringAsFixed(2)}' : '—',
          color: AppColors.purple,
        )),
      ]),
    ]);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 9, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
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

class _FinancialPieChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinancialProvider>();
    if (fin.transactions.isEmpty) return const _EmptyChart(message: 'No financial data yet');
    final income = fin.totalIncome;
    final expenses = fin.totalExpenses;
    if (income == 0 && expenses == 0) return const _EmptyChart(message: 'No financial data yet');

    return Row(
      children: [
        SizedBox(
          height: 150,
          width: 150,
          child: PieChart(PieChartData(
            sections: [
              if (income > 0) PieChartSectionData(value: income, color: AppColors.green, title: '', radius: 60),
              if (expenses > 0) PieChartSectionData(value: expenses, color: AppColors.red, title: '', radius: 60),
            ],
            sectionsSpace: 2,
            centerSpaceRadius: 30,
          )),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendItem(color: AppColors.green, label: 'Income', value: '${CurrencyFormatter.currencySymbol}${income.toStringAsFixed(0)}'),
            const SizedBox(height: 10),
            _LegendItem(color: AppColors.red, label: 'Expenses', value: '${CurrencyFormatter.currencySymbol}${expenses.toStringAsFixed(0)}'),
            const SizedBox(height: 10),
            // Not a pie slice — derived value. Amber (not expense-red)
            // when negative so it can't be confused with Expenses.
            _LegendItem(
              color: fin.netProfit >= 0 ? AppColors.cyan : AppColors.amber,
              label: fin.netProfit >= 0 ? 'Net Profit' : 'Net Loss',
              value:
                  '${fin.netProfit < 0 ? '-' : ''}${CurrencyFormatter.currencySymbol}${fin.netProfit.abs().toStringAsFixed(0)}',
            ),
          ],
        )),
      ],
    );
  }
}

class _MortalityPieChart extends StatelessWidget {
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

    return Row(
      children: [
        SizedBox(
          height: 150,
          width: 150,
          child: PieChart(PieChartData(
            sections: byCause.entries.map((e) => PieChartSectionData(
              value: e.value.toDouble(),
              color: _colors[e.key] ?? AppColors.textMuted,
              title: '',
              radius: 60,
            )).toList(),
            sectionsSpace: 2,
            centerSpaceRadius: 30,
          )),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: byCause.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LegendItem(
              color: _colors[e.key] ?? AppColors.textMuted,
              label: e.key.name[0].toUpperCase() + e.key.name.substring(1),
              value: '${e.value}',
            ),
          )).toList(),
        )),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
      Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
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
    