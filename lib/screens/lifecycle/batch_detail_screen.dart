import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../providers/batch_provider.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/mortality_provider.dart';
import '../../providers/vaccination_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/units.dart';

/// A batch's command center — lifecycle timeline plus KPIs aggregated
/// from every module (eggs, feed, mortality, vaccination), the way
/// FarmNest's batch detail page works.
class BatchDetailScreen extends StatelessWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) {
    // Watch every provider so the page stays live as records change.
    final batch = context.watch<BatchProvider>().getBatchById(batchId);
    if (batch == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Batch')),
        body: const Center(child: Text('This batch no longer exists.')),
      );
    }

    final eggs = context.watch<EggProductionProvider>();
    final feed = context.watch<FeedProvider>();
    final mortality = context.watch<MortalityProvider>();
    final vacc = context.watch<VaccinationProvider>();

    // Records reference a batch by its name (the app's batch ref).
    final ref = batch.name;
    final batchEggs = eggs.records.where((e) => e.batchId == ref);
    final totalEggs = batchEggs.fold(0, (s, e) => s + e.eggCount);
    final batchFeed = feed.records.where((f) => f.batchId == ref);
    final feedKg = batchFeed.fold(0.0, (s, f) => s + f.totalKg);
    final feedCost = batchFeed.fold(0.0, (s, f) => s + f.totalCost);
    final batchDeaths = mortality.records
        .where((m) => m.batchId == ref)
        .fold(0, (s, m) => s + m.count);
    final batchVacc =
        vacc.vaccinations.where((v) => v.batchId == ref).toList();
    final vaccDone = batchVacc.where((v) => v.administeredDate != null).length;

    // FCR (layers): kg feed per dozen eggs. A quick efficiency read.
    final dozens = totalEggs / 12.0;
    final fcr = dozens > 0 ? feedKg / dozens : 0.0;
    final ageWeeks = (batch.ageInDays / 7).floor();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(batch.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _StagePill(stage: _stageForAge(ageWeeks, batch.type)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${batch.typeName}${batch.source != null ? " · ${batch.source}" : ""} · $ageWeeks weeks old',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          _timeline(ageWeeks, batch.type),
          const SizedBox(height: 20),

          _sectionLabel('Overview'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _kpi('Initial Birds', '${batch.initialCount}', AppColors.textPrimary),
              _kpi('Current Birds', '${batch.currentCount}', AppColors.green),
              _kpi('Mortality Rate',
                  '${batch.mortalityRate.toStringAsFixed(1)}%', AppColors.red),
              _kpi('Birds Lost', '$batchDeaths', AppColors.red),
              _kpi('Total Crates', Units.crateShort(totalEggs), AppColors.amber),
              _kpi('Feed Used', '${Units.bagShort(feedKg)} bags', AppColors.cyan),
              _kpi('Feed Cost',
                  '${CurrencyFormatter.currencySymbol}${feedCost.toStringAsFixed(0)}',
                  AppColors.cyan),
              _kpi('FCR', fcr > 0 ? fcr.toStringAsFixed(2) : '—',
                  AppColors.purple),
            ],
          ),
          const SizedBox(height: 20),

          _sectionLabel('Health'),
          const SizedBox(height: 8),
          _infoRow('Vaccinations completed',
              '$vaccDone of ${batchVacc.length}'),
          _infoRow('Entry date',
              DateFormat('d MMM yyyy').format(batch.hatchDate)),
          if (batch.initialCost != null)
            _infoRow('Purchase cost',
                '${CurrencyFormatter.currencySymbol}${batch.initialCost!.toStringAsFixed(0)}'),
          if (batch.description != null && batch.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionLabel('Notes'),
            const SizedBox(height: 6),
            Text(batch.description!,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );

  Widget _kpi(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Text(value,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _timeline(int ageWeeks, BatchType type) {
    final current = _stageForAge(ageWeeks, type);
    const stages = ['Arrival', 'Brooding', 'Growing', 'Laying'];
    final currentIndex = stages.indexOf(current);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(stages.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = (i ~/ 2) < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? AppColors.green : AppColors.border,
              ),
            );
          }
          final idx = i ~/ 2;
          final reached = idx <= currentIndex;
          final isCurrent = idx == currentIndex;
          return Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? AppColors.amber
                      : reached
                          ? AppColors.green
                          : AppColors.surfaceLight,
                  border: Border.all(
                    color: reached ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: reached
                    ? Icon(isCurrent ? Icons.egg_alt : Icons.check,
                        size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(stages[idx],
                  style: TextStyle(
                    color:
                        reached ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 9,
                  )),
            ],
          );
        }),
      ),
    );
  }

  /// Lifecycle stage derived from age and bird type — matches the
  /// table's stage semantics but expressed as the timeline steps.
  String _stageForAge(int weeks, BatchType type) {
    if (weeks <= 4) return 'Brooding';
    if (weeks <= 18) return 'Growing';
    return 'Laying';
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});
  final String stage;

  @override
  Widget build(BuildContext context) {
    final color = switch (stage) {
      'Brooding' => AppColors.amber,
      'Growing' => AppColors.cyan,
      _ => AppColors.green,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(stage,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
