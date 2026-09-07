import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../models/egg_production.dart';
import '../../models/feed_record.dart';
import '../../models/mortality.dart';
import '../../models/vaccination.dart';
import '../../models/measurement.dart';
import '../egg_production/egg_production_screen.dart';
import '../feed/feed_screen.dart';
import '../mortality/mortality_screen.dart';
import '../vaccination/vaccination_screen.dart';
import '../monitoring/measurement_screen.dart';
import '../../providers/batch_provider.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/mortality_provider.dart';
import '../../providers/vaccination_provider.dart';
import '../../providers/poultry_house_provider.dart';
import '../../providers/measurement_provider.dart';
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
    final house = context.watch<PoultryHouseProvider>().byId(batch.coopId);

    // Records reference a batch by its ID (legacy rows may still hold
    // the name), so match either.
    final refs = {batch.id, batch.name};
    final batchEggs = eggs.records.where((e) => refs.contains(e.batchId));
    final totalEggs = batchEggs.fold(0, (s, e) => s + e.eggCount);
    final batchFeed = feed.records.where((f) => refs.contains(f.batchId));
    final feedKg = batchFeed.fold(0.0, (s, f) => s + f.totalKg);
    final feedCost = batchFeed.fold(0.0, (s, f) => s + f.totalCost);
    final costPerBird = batch.currentCount > 0
        ? ((batch.initialCost ?? 0) + feedCost) / batch.currentCount
        : 0.0;
    final batchDeaths = mortality.records
        .where((m) => refs.contains(m.batchId))
        .fold(0, (s, m) => s + m.count);
    final batchVacc =
        vacc.vaccinations.where((v) => refs.contains(v.batchId)).toList();
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
              child: _StagePill(stage: batch.currentStage.label),
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

          _timeline(batch),
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
              _kpi('Cost / bird',
                  costPerBird > 0
                      ? '${CurrencyFormatter.currencySymbol}${costPerBird.toStringAsFixed(2)}'
                      : '—',
                  AppColors.amber),
            ],
          ),
          const SizedBox(height: 20),

          // ---- Actions: everything here is filed against THIS batch ----
          _sectionLabel('Record for this batch'),
          const SizedBox(height: 8),
          _actionGrid(context, batch),
          const SizedBox(height: 22),

          // ---- Recent activity, per module, for this batch only ----
          _recentEggs(context, batch, batchEggs.toList()),
          _recentFeed(context, batch, batchFeed.toList()),
          _recentDeaths(context, batch,
              mortality.records.where((m) => refs.contains(m.batchId)).toList()),
          _recentVaccinations(context, batch, batchVacc),

          // Weight / temperature / water at a glance, so the readings the
          // monitoring screen collects are visible here rather than buried
          // one more tap away.
          _flockReadings(context, batch),

          _sectionLabel('Health'),
          const SizedBox(height: 8),
          _infoRow('Vaccinations completed',
              '$vaccDone of ${batchVacc.length}'),
          _infoRow('Entry date',
              DateFormat('d MMM yyyy').format(batch.hatchDate)),
          if (batch.supplier != null && batch.supplier!.isNotEmpty)
            _infoRow('Source of chicks', batch.supplier!),
          if (house != null) _infoRow('House', house.name),
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

  Widget _timeline(Batch batch) {
    final current = _timelineStage(batch);
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
  /// The timeline node the flock is currently at, mapped from its
  /// age-based [Batch.currentStage] so the timeline, the app-bar pill,
  /// and the Batches list always agree.
  String _timelineStage(Batch batch) {
    switch (batch.currentStage) {
      case BatchStage.brooding:
        return 'Brooding';
      case BatchStage.grower:
        return 'Growing';
      case BatchStage.layer:
        return 'Laying';
    }
  }
  // =================================================================
  // Batch hub: act on THIS batch, and see what has been recorded
  // against it, without going near a batch picker.
  // =================================================================

  /// The four things a farmer does to a flock. Each opens the module's
  /// own form with this batch fixed, so the flock cannot be mis-picked.
  Widget _actionGrid(BuildContext context, Batch batch) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _BatchAction(
          label: 'Log eggs',
          icon: Icons.egg_outlined,
          color: AppColors.amber,
          onTap: () => EggProductionScreen.showAddDialog(context,
              presetBatchId: batch.id),
        ),
        _BatchAction(
          label: 'Log feed',
          icon: Icons.grass,
          color: AppColors.cyan,
          onTap: () => FeedScreen.showLogDialog(
              context, context.read<FeedProvider>(),
              presetBatchId: batch.id),
        ),
        _BatchAction(
          label: 'Record deaths',
          icon: Icons.trending_down,
          color: AppColors.red,
          onTap: () => MortalityScreen.showAddDialog(context,
              presetBatchId: batch.id),
        ),
        _BatchAction(
          label: 'Schedule vaccine',
          icon: Icons.vaccines_outlined,
          color: AppColors.green,
          onTap: () => VaccinationScreen.showAddDialog(context,
              presetBatchId: batch.id),
        ),
        _BatchAction(
          label: 'Log monitoring',
          icon: Icons.monitor_weight_outlined,
          color: AppColors.purple,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MeasurementScreen(batch: batch))),
        ),
      ],
    );
  }

  /// Section heading with a "See all" that opens the full,
  /// batch-filtered list. Only shown when there is more than we display.
  Widget _activityHeader(String label,
      {VoidCallback? onSeeAll, int total = 0, int shown = 3}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _sectionLabel(label),
          if (onSeeAll != null && total > shown)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'See all $total',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _activityRow(String left, String right, {String? sub, Color? tint}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(left,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  if (sub != null && sub.isNotEmpty)
                    Text(sub,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Text(right,
                style: TextStyle(
                    color: tint ?? AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _nothingYet(String text) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );

  /// Newest first.
  List<T> _sortedByDate<T>(List<T> items, DateTime Function(T) dateOf) {
    final sorted = [...items]..sort((a, b) => dateOf(b).compareTo(dateOf(a)));
    return sorted;
  }

  Widget _recentEggs(
      BuildContext context, Batch batch, List<EggProduction> records) {
    final all = _sortedByDate(records, (e) => e.date);
    Widget row(EggProduction e, {bool longDate = false}) => _activityRow(
          DateFormat(longDate ? 'd MMM yyyy' : 'd MMM').format(e.date),
          Units.crateShort(e.eggCount),
          sub: [
            if (e.period != null) e.period!,
            if (e.damagedCount > 0) '${e.damagedCount} damaged',
          ].join(' · '),
          tint: AppColors.amber,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityHeader('Recent egg collection',
            total: all.length,
            onSeeAll: () => _openAll(context, batch, 'Egg collection',
                all.map((e) => row(e, longDate: true)).toList())),
        if (all.isEmpty)
          _nothingYet('No eggs logged for this batch yet.')
        else
          ...all.take(3).map((e) => row(e)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _recentFeed(
      BuildContext context, Batch batch, List<FeedRecord> records) {
    final all = _sortedByDate(records, (f) => f.date);
    Widget row(FeedRecord f, {bool longDate = false}) => _activityRow(
          DateFormat(longDate ? 'd MMM yyyy' : 'd MMM').format(f.date),
          '${Units.bagShort(f.totalKg)} bags',
          sub: f.feedTypeName,
          tint: AppColors.cyan,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityHeader('Recent feed',
            total: all.length,
            onSeeAll: () => _openAll(context, batch, 'Feed consumption',
                all.map((f) => row(f, longDate: true)).toList())),
        if (all.isEmpty)
          _nothingYet('No feed logged for this batch yet.')
        else
          ...all.take(3).map((f) => row(f)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _recentDeaths(
      BuildContext context, Batch batch, List<Mortality> records) {
    final all = _sortedByDate(records, (m) => m.date);
    Widget row(Mortality m, {bool longDate = false}) => _activityRow(
          DateFormat(longDate ? 'd MMM yyyy' : 'd MMM').format(m.date),
          '${m.count}',
          sub: m.causeName,
          tint: AppColors.red,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityHeader('Recent losses',
            total: all.length,
            onSeeAll: () => _openAll(context, batch, 'Mortality',
                all.map((m) => row(m, longDate: true)).toList())),
        if (all.isEmpty)
          _nothingYet('No deaths recorded for this batch.')
        else
          ...all.take(3).map((m) => row(m)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _recentVaccinations(
      BuildContext context, Batch batch, List<Vaccination> records) {
    // Doses still owed matter more than doses already given, so those
    // come first regardless of date.
    final now = DateTime.now();
    final pending = records.where((v) => v.administeredDate == null).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final given = records.where((v) => v.administeredDate != null).toList()
      ..sort((a, b) => b.administeredDate!.compareTo(a.administeredDate!));
    final shown = [...pending.take(2), ...given.take(1)];

    Widget row(Vaccination v) {
      final overdue =
          v.administeredDate == null && v.scheduledDate.isBefore(now);
      return _activityRow(
        v.vaccineName,
        v.administeredDate != null ? 'Given' : (overdue ? 'Overdue' : 'Due'),
        sub: DateFormat('d MMM yyyy')
            .format(v.administeredDate ?? v.scheduledDate),
        tint: v.administeredDate != null
            ? AppColors.green
            : (overdue ? AppColors.red : AppColors.amber),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityHeader('Vaccinations',
            total: records.length,
            onSeeAll: () => _openAll(context, batch, 'Vaccinations',
                [...pending, ...given].map(row).toList())),
        if (shown.isEmpty)
          _nothingYet('No vaccines scheduled for this batch yet.')
        else
          ...shown.map(row),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Latest weight / temperature / water for this flock, with a link into
  /// the full monitoring screen. Surfaces the readings (and the fact that
  /// monitoring exists) instead of hiding them behind the action tile.
  Widget _flockReadings(BuildContext context, Batch batch) {
    final m = context.watch<MeasurementProvider>();
    void open() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MeasurementScreen(batch: batch)));

    Color colorFor(MeasurementType t) => switch (t) {
          MeasurementType.weight => AppColors.purple,
          MeasurementType.temperature => AppColors.amber,
          MeasurementType.water => AppColors.cyan,
        };

    Widget readingRow(MeasurementType t) {
      final latest = m.latest(batch.id, t);
      return _activityRow(
        t.label,
        latest != null ? '${_fmtReading(latest.value)} ${t.unit}' : '—',
        sub: latest != null
            ? DateFormat('d MMM yyyy').format(latest.date)
            : 'Not logged yet',
        tint: latest != null ? colorFor(t) : AppColors.textSecondary,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Flock readings'),
              GestureDetector(
                onTap: open,
                child: Text(
                  'Log / view',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        readingRow(MeasurementType.weight),
        readingRow(MeasurementType.temperature),
        readingRow(MeasurementType.water),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Whole numbers stay clean (1450 g); fractional readings keep one place.
  String _fmtReading(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// The full, batch-filtered list behind "See all".
  void _openAll(
      BuildContext context, Batch batch, String title, List<Widget> rows) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('$title · ${batch.name}')),
        body: rows.isEmpty
            ? Center(
                child: Text('Nothing recorded yet.',
                    style: TextStyle(color: AppColors.textSecondary)))
            : ListView(padding: const EdgeInsets.all(16), children: rows),
      ),
    ));
  }
}

/// One tappable action tile on the batch hub.
class _BatchAction extends StatelessWidget {
  const _BatchAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
