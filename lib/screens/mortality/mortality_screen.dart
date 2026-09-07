import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/caps.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/mortality.dart';
import '../../providers/mortality_provider.dart';
import '../../providers/batch_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/html_widgets.dart';

class MortalityScreen extends StatelessWidget {
  const MortalityScreen({super.key});

  static final List<Color> _causeColors = [
    AppColors.red, AppColors.amber, AppColors.purple,
    AppColors.cyan, AppColors.blue, AppColors.green,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<MortalityProvider, BatchProvider>(
      builder: (context, mortProvider, batchProvider, _) {
        final logs        = mortProvider.records;
        final totalDeaths = mortProvider.totalCount;
        final totalBirds  = batchProvider.batches.fold(0, (s, b) => s + b.currentCount);
        final survival    = totalBirds > 0
            ? '${(totalBirds / (totalBirds + totalDeaths) * 100).toStringAsFixed(1)}%'
            : '—%';
        final now       = DateTime.now();
        final weekDeaths = logs
            .where((r) => r.date.isAfter(now.subtract(const Duration(days: 7))))
            .fold(0, (s, r) => s + r.count);
        final causes = logs.map((r) => r.causeName).toSet().length;

        final causeMap = <String, int>{};
        for (final r in logs) {
          causeMap[r.causeName] = (causeMap[r.causeName] ?? 0) + r.count;
        }
        final sortedCauses = causeMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.monitor_heart_outlined,
                title: 'Mortality & Health Log',
                subtitle: 'Record deaths with cause-of-death tags and survival analytics',
                action: Caps.of(context).canRecordDeaths
                    ? PrimaryBtn(label: '+ Log Deaths', onPressed: () => showAddDialog(context))
                    : null,
              ),

              ..._buildAlert(totalBirds, weekDeaths),

              KpiGrid(children: [
                KpiCard(label: 'Survival Rate', value: survival, accentColor: AppColors.green),
                KpiCard(label: 'Total Deaths', value: '$totalDeaths', accentColor: AppColors.red),
                KpiCard(label: 'This Week', value: '$weekDeaths', accentColor: AppColors.amber),
                KpiCard(label: 'Causes Tagged', value: '$causes', accentColor: AppColors.cyan),
              ]),
              const SizedBox(height: 14),

              // Early-warning: a spike or a cause cluster in recent deaths.
              _diseaseThreatBanner(mortProvider),
              // Deaths week by week, so a rising trend is visible at a glance.
              _trendCard(context, mortProvider),
              const SizedBox(height: 18),

              _twoCol(
                left: HtmlCard(
                  header: const HtmlCardHeader(icon: Icons.pie_chart_outline, title: 'Cause of Death Breakdown'),
                  body: sortedCauses.isEmpty
                      ? const HtmlEmptyState(icon: Icons.pie_chart_outline, message: 'Log deaths to see breakdown.')
                      : Column(
                          children: sortedCauses.asMap().entries.map((e) {
                            final pct = totalDeaths > 0
                                ? (e.value.value / totalDeaths * 100).round()
                                : 0;
                            return CauseBarRow(
                              label: e.value.key,
                              percent: pct,
                              color: _causeColors[e.key % _causeColors.length],
                              valueLabel: '$pct%',
                            );
                          }).toList(),
                        ),
                ),
                right: HtmlCard(
                  header: const HtmlCardHeader(icon: Icons.list_alt_outlined, title: 'Death Records'),
                  bodyPadding: EdgeInsets.zero,
                  body: logs.isEmpty
                      ? HtmlEmptyState(
                          icon: Icons.monitor_heart_outlined,
                          message: 'No mortality records yet.',
                          action: Caps.of(context).canRecordDeaths ? PrimaryBtn(label: '+ Log Deaths', small: true, onPressed: () => showAddDialog(context)) : null,
                        )
                      : _logsTable(context, logs, mortProvider),
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  /// Weekly-loss threshold alert, like FarmNest's mortality warnings.
  /// >2% of the flock in a week is a red flag; >1% is worth watching.
  /// Red banner shown when recent deaths spike or cluster on one cause,
  /// the disease-threat early warning. Nothing shows when all is calm.
  Widget _diseaseThreatBanner(MortalityProvider provider) {
    final threat = provider.diseaseThreat();
    if (threat == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(threat.title, style: GoogleFonts.inter(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(threat.detail, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Weekly deaths as a bar chart, so a rising trend over time is visible
  /// at a glance rather than buried in the records list.
  Widget _trendCard(BuildContext context, MortalityProvider provider) {
    final weekly = provider.weeklyDeaths(weeks: 8);
    final maxDeaths = weekly.fold(0, (m, w) => w.deaths > m ? w.deaths : m);
    final hasData = weekly.any((w) => w.deaths > 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: HtmlCard(
        header: HtmlCardHeader(
          icon: Icons.show_chart,
          title: 'Deaths Over Time',
          trailing: TagChip(label: 'last 8 weeks', color: AppColors.red),
        ),
        body: !hasData
            ? Text(
                'No deaths logged yet. As you record deaths, the weekly trend '
                'shows here and warns you of a sudden rise.',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 170,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (maxDeaths + 1).toDouble(),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => AppColors.surfaceLight,
                            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                              '${weekly[group.x].deaths} died',
                              TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= weekly.length) return const SizedBox.shrink();
                                final d = weekly[i].weekStart;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('${d.day}/${d.month}', style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: (maxDeaths / 3).ceilToDouble().clamp(1, 9999),
                              getTitlesWidget: (value, meta) => Text(value.toInt().toString(),
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border, strokeWidth: 0.5),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (var i = 0; i < weekly.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                toY: weekly[i].deaths.toDouble(),
                                color: AppColors.red,
                                width: 14,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              )
                            ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Each bar is one week (starting Monday). A tall bar after low ones is worth a closer look.',
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10.5),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildAlert(int totalBirds, int weekDeaths) {
    if (totalBirds <= 0 || weekDeaths <= 0) return const [];
    final pct = weekDeaths / (totalBirds + weekDeaths) * 100;
    final (color, icon, msg) = pct > 2
        ? (
            AppColors.red,
            Icons.error_outline,
            'High mortality: $weekDeaths losses this week (${pct.toStringAsFixed(1)}% of the flock). '
                'Check water, ventilation, disease signs — consider a vet.'
          )
        : pct > 1
            ? (
                AppColors.amber,
                Icons.warning_amber_rounded,
                'Watch closely: $weekDeaths losses this week (${pct.toStringAsFixed(1)}% of the flock). '
                    'Review the cause breakdown below.'
              )
            : (Colors.transparent, Icons.check, '');
    if (msg.isEmpty) return const [];
    return [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
        ]),
      ),
    ];
  }

  Widget _twoCol({required Widget left, required Widget right}) {
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth < 500) return Column(children: [left, right]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left), const SizedBox(width: 14), Expanded(child: right),
      ]);
    });
  }

  Widget _logsTable(BuildContext context, List<Mortality> logs, MortalityProvider provider) {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    final bp = context.read<BatchProvider>();
    return HtmlTable(
      headers: ['Date', 'Deaths', 'Cause', 'Batch', ''],
      dates: sorted.map((r) => r.date).toList(),
      rows: sorted.map((r) {
        final label = bp.batchLabel(r.batchId);
        return [
        Text(DateFormat('d MMM yyyy').format(r.date), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Text('${r.count}', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w500, fontSize: 12)),
        Text(r.causeName, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
        Text(label.length > 12 ? '${label.substring(0, 12)}…' : label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        // Vet & owner/manager can annotate the cause; only owner/manager
        // can delete. A worker who logged it cannot change it after.
        Builder(builder: (context) {
          final caps = Caps.of(context);
          if (!caps.canEditDeaths && !caps.canAmend) return const SizedBox.shrink();
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (caps.canEditDeaths) EditBtn(onTap: () => _showEditDialog(context, r, provider)),
            if (caps.canAmend) DelBtn(onTap: () => _confirmDelete(context, r, provider)),
          ]);
        }),
      ];
      }).toList(),
    );
  }

  /// Opens the mortality log. When [presetBatchId] is given (the batch
  /// hub passes it), the flock is fixed and shown locked, so deaths
  /// cannot be recorded against the wrong batch.
  static void showAddDialog(BuildContext context, {String? presetBatchId}) {
    final countCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    int selectedCause = 0;
    final batches = context.read<BatchProvider>().batches;
    // Records reference batches by ID; 'All' means the whole flock.
    final batchOptions = {for (final b in batches) b.id: b.name, 'All': 'All'};
    String selectedBatch = presetBatchId ?? batchOptions.keys.first;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Log Mortality'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: 'Date',
                child: HtmlDateTile(
                  date: selectedDate,
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (d != null) ss(() => selectedDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Number of Deaths',
                child: TextField(controller: countCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 7')),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Cause of Death',
                child: DropdownButtonFormField<int>(
                  initialValue: selectedCause,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: MortalityCause.values.map((c) => DropdownMenuItem(
                    value: c.index,
                    child: Text(c.name[0].toUpperCase() + c.name.substring(1), style: TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedCause = v ?? 0),
                ),
              ),
              const SizedBox(height: 12),
              if (presetBatchId != null)
                LockedBatchField(
                    batchName: batchOptions[presetBatchId] ?? presetBatchId)
              else
                HtmlFormField(
                  label: 'Affected Batch',
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedBatch,
                    dropdownColor: AppColors.surfaceLight,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: htmlInputDec(),
                    items: batchOptions.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: TextStyle(color: AppColors.textPrimary)),
                    )).toList(),
                    onChanged: (v) => ss(() => selectedBatch = v ?? selectedBatch),
                  ),
                ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Notes / Vet Observations',
                child: TextField(controller: notesCtrl, maxLines: 3, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Symptoms, treatments attempted...')),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final count = int.tryParse(countCtrl.text.trim()) ?? 0;
                if (count <= 0) return;
                context.read<MortalityProvider>().addRecord(Mortality(
                  batchId: selectedBatch,
                  count: count,
                  date: selectedDate,
                  cause: MortalityCause.values[selectedCause],
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                ));
                // Keep the batch's live bird count in sync
                context.read<BatchProvider>().adjustCount(selectedBatch, -count);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Mortality logged — bird count updated'),
                  backgroundColor: AppColors.green.withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: const Text('Save Record'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Mortality mort, MortalityProvider provider) {
    final countCtrl = TextEditingController(text: '${mort.count}');
    int selectedCause = mort.cause?.index ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Mortality Record'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(label: 'Number of Birds', child: TextField(controller: countCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Count'))),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Cause',
                child: DropdownButtonFormField<int>(
                  initialValue: selectedCause,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: MortalityCause.values.map((c) => DropdownMenuItem(
                    value: c.index,
                    child: Text(c.name[0].toUpperCase() + c.name.substring(1), style: TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedCause = v ?? 0),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final count = int.tryParse(countCtrl.text) ?? 0;
                if (count <= 0) return;
                provider.updateRecord(mort.copyWith(count: count, cause: MortalityCause.values[selectedCause]));
                // Apply the difference to the batch's live count
                context.read<BatchProvider>().adjustCount(mort.batchId, mort.count - count);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record updated'), backgroundColor: AppColors.cyan, behavior: SnackBarBehavior.floating));
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Mortality mort, MortalityProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: Text('This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.removeRecord(mort.id);
              // Restore the birds to the batch's live count
              context.read<BatchProvider>().adjustCount(mort.batchId, mort.count);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
