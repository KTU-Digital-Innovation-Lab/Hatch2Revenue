import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/financial_provider.dart';
import '../../providers/mortality_provider.dart';
import '../../providers/batch_provider.dart';
import '../../models/mortality.dart';
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';

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
              const Text('📊', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Visualize your farm performance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSummaryRow(context),
          const SizedBox(height: 16),
          _ChartCard(title: 'Egg Production (Last 10)', emoji: '🥚', child: _EggProductionChart()),
          const SizedBox(height: 16),
          _ChartCard(title: 'Financial Breakdown', emoji: '💰', child: _FinancialPieChart()),
          const SizedBox(height: 16),
          _ChartCard(title: 'Mortality by Cause', emoji: '⚠️', child: _MortalityPieChart()),
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
        Expanded(child: _MiniStat(label: 'TOTAL EGGS', value: '${eggs.totalEggs}', color: AppColors.green)),
        const SizedBox(width: 10),
        Expanded(child: _MiniStat(label: 'NET PROFIT', value: '${CurrencyFormatter.currencySymbol}${fin.netProfit.toStringAsFixed(0)}', color: fin.netProfit >= 0 ? AppColors.cyan : AppColors.red)),
      ],
    );
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String emoji;
  final Widget child;
  const _ChartCard({required this.title, required this.emoji, required this.child});

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
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
    final maxY = last10.map((r) => r.eggCount.toDouble()).reduce((a, b) => a > b ? a : b);

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
                '${last10[group.x].eggCount} eggs',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
                    child: Text('${d.day}/${d.month}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)),
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
            getDrawingHorizontalLine: (v) => const FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          barGroups: last10.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(
              toY: e.value.eggCount.toDouble(),
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
            _LegendItem(
              color: fin.netProfit >= 0 ? AppColors.cyan : AppColors.red,
              label: 'Net Profit',
              value: '${CurrencyFormatter.currencySymbol}${fin.netProfit.toStringAsFixed(0)}',
            ),
          ],
        )),
      ],
    );
  }
}

class _MortalityPieChart extends StatelessWidget {
  static const _colors = {
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
      Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
          const Text('📈', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      )),
    );
  }
}
