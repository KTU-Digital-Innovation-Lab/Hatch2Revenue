import 'package:flutter/material.dart';
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

  static const List<Color> _causeColors = [
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
                action: PrimaryBtn(label: '+ Log Deaths', onPressed: () => _showAddDialog(context)),
              ),

              ..._buildAlert(totalBirds, weekDeaths),

              KpiGrid(children: [
                KpiCard(label: 'Survival Rate', value: survival, accentColor: AppColors.green),
                KpiCard(label: 'Total Deaths', value: '$totalDeaths', accentColor: AppColors.red),
                KpiCard(label: 'This Week', value: '$weekDeaths', accentColor: AppColors.amber),
                KpiCard(label: 'Causes Tagged', value: '$causes', accentColor: AppColors.cyan),
              ]),
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
                          action: PrimaryBtn(label: '+ Log Deaths', small: true, onPressed: () => _showAddDialog(context)),
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
    return HtmlTable(
      headers: ['Date', 'Deaths', 'Cause', 'Batch', ''],
      rows: sorted.map((r) => [
        Text(DateFormat('d MMM yyyy').format(r.date), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Text('${r.count}', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w500, fontSize: 12)),
        Text(r.causeName, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
        Text(r.batchId.length > 8 ? r.batchId.substring(0, 8) : r.batchId, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          EditBtn(onTap: () => _showEditDialog(context, r, provider)),
          DelBtn(onTap: () => _confirmDelete(context, r, provider)),
        ]),
      ]).toList(),
    );
  }

  void _showAddDialog(BuildContext context) {
    final countCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    int selectedCause = 0;
    final batches = context.read<BatchProvider>().batches;
    final batchOptions = [...batches.map((b) => b.name), 'All'];
    String selectedBatch = batchOptions.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Log Mortality'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(label: 'Date', child: HtmlDateTile(date: DateTime.now())),
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
              HtmlFormField(
                label: 'Affected Batch',
                child: DropdownButtonFormField<String>(
                  initialValue: selectedBatch,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: batchOptions.map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b, style: TextStyle(color: AppColors.textPrimary)),
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
                  date: DateTime.now(),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated'), backgroundColor: AppColors.cyan, behavior: SnackBarBehavior.floating));
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
