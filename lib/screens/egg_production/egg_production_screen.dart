import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/egg_production.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/batch_provider.dart';
import '../../providers/quick_action_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/html_widgets.dart';

class EggProductionScreen extends StatelessWidget {
  const EggProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<EggProductionProvider, BatchProvider, QuickActionProvider>(
      builder: (context, eggProvider, batchProvider, quickAction, _) {
        if (quickAction.action == 'recordEggs') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            quickAction.clear();
            _showAddDialog(context);
          });
        }

        final logs     = eggProvider.records;
        final total    = eggProvider.totalEggs;
        final damaged  = eggProvider.totalDamagedEggs;
        final latestHd = logs.isNotEmpty ? '${logs.last.productionRate.toStringAsFixed(1)}%' : '—%';
        final avgPerDay = eggProvider.averagePerDay;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: '🥚 Egg Production Tracker',
                subtitle: 'Log daily tallies, damaged eggs, and Hen-Day Production %',
                action: PrimaryBtn(label: '+ Log Today\'s Eggs', onPressed: () => _showAddDialog(context)),
              ),

              KpiCard(label: 'Total Eggs', value: '$total', icon: '🥚', accentColor: AppColors.green),
              const SizedBox(height: 12),
              KpiCard(label: 'Damaged', value: '$damaged', icon: '💔', accentColor: AppColors.red),
              const SizedBox(height: 12),
              KpiCard(label: 'HD% (latest)', value: latestHd, icon: '📈', accentColor: AppColors.amber),
              const SizedBox(height: 12),
              KpiCard(label: 'Days Logged', value: '${logs.length}', icon: '📅', accentColor: AppColors.cyan),
              const SizedBox(height: 18),

              HtmlCard(
                header: HtmlCardHeader(
                  title: '📅 Monthly Production Calendar',
                  trailing: TagChip(label: _monthLabel(), color: AppColors.green),
                ),
                body: Column(
                  children: [
                    _buildCalendar(logs, avgPerDay),
                    const SizedBox(height: 10),
                    Row(children: [
                      _legend('🟢', 'High',    AppColors.green),
                      const SizedBox(width: 12),
                      _legend('🟡', 'Average', AppColors.amber),
                      const SizedBox(width: 12),
                      _legend('🔴', 'Low',     AppColors.red),
                      const SizedBox(width: 12),
                      _legend('⬜', 'No data', AppColors.textMuted),
                    ]),
                  ],
                ),
              ),

              HtmlCard(
                header: const HtmlCardHeader(title: '📋 All Egg Logs'),
                bodyPadding: EdgeInsets.zero,
                body: logs.isEmpty
                    ? HtmlEmptyState(
                        icon: '🥚',
                        message: 'No egg records yet.',
                        action: PrimaryBtn(label: '+ Log Eggs', small: true, onPressed: () => _showAddDialog(context)),
                      )
                    : _logsTable(context, logs, eggProvider),
              ),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  String _monthLabel() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[now.month - 1].toUpperCase()} ${now.year}';
  }

  Widget _legend(String icon, String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(icon, style: const TextStyle(fontSize: 10)),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.dmMono(color: color, fontSize: 9)),
  ]);

  Widget _buildCalendar(List<EggProduction> logs, double avgPerDay) {
    final recent = logs.length > 21 ? logs.sublist(logs.length - 21) : logs;
    final cells  = <Widget>[];

    for (final e in recent) {
      String cls;
      Color bg, fg, border;
      if (avgPerDay <= 0) {
        cls = 'avg';
      } else if (e.eggCount >= avgPerDay * 1.05) {
        cls = 'good';
      } else if (e.eggCount >= avgPerDay * 0.9) {
        cls = 'avg';
      } else {
        cls = 'low';
      }
      switch (cls) {
        case 'good':
          bg = AppColors.green.withValues(alpha: 0.13); fg = AppColors.green; border = AppColors.green.withValues(alpha: 0.2);
          break;
        case 'low':
          bg = AppColors.red.withValues(alpha: 0.09); fg = AppColors.red; border = AppColors.red.withValues(alpha: 0.15);
          break;
        default:
          bg = AppColors.amber.withValues(alpha: 0.10); fg = AppColors.amber; border = AppColors.amber.withValues(alpha: 0.18);
      }
      final dayLabel = '${e.date.month}/${e.date.day}';
      final numLabel = e.eggCount >= 1000 ? '${(e.eggCount / 1000).toStringAsFixed(1)}k' : '${e.eggCount}';
      cells.add(_eggCell(dayLabel, numLabel, bg, fg, border));
    }

    while (cells.length < 21) {
      cells.add(_eggCell('—', '', AppColors.surfaceLight, AppColors.textMuted, AppColors.border));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      children: cells,
    );
  }

  Widget _eggCell(String day, String num, Color bg, Color fg, Color border) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: border)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(day, style: GoogleFonts.dmMono(color: fg, fontSize: 8)),
        if (num.isNotEmpty)
          Text(num, style: GoogleFonts.syne(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _logsTable(BuildContext context, List<EggProduction> logs, EggProductionProvider provider) {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    return HtmlTable(
      headers: ['Date', 'Total Eggs', 'Damaged', 'HD%', ''],
      rows: sorted.map((e) => [
        Text(DateFormat('d MMM yyyy').format(e.date), style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 11)),
        Text('${e.eggCount}', style: GoogleFonts.dmMono(color: AppColors.green, fontWeight: FontWeight.w500, fontSize: 12)),
        Text('${e.damagedCount}', style: GoogleFonts.dmMono(color: e.damagedCount > 0 ? AppColors.red : AppColors.textSecondary, fontSize: 11)),
        Text('${e.productionRate.toStringAsFixed(1)}%', style: GoogleFonts.dmMono(color: AppColors.textPrimary, fontSize: 11)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          EditBtn(onTap: () => _showEditDialog(context, e, provider)),
          DelBtn(onTap: () => provider.removeRecord(e.id)),
        ]),
      ]).toList(),
    );
  }

  void _showAddDialog(BuildContext context) {
    final totalCtrl   = TextEditingController();
    final damagedCtrl = TextEditingController();
    final hensCtrl    = TextEditingController();
    final notesCtrl   = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🥚 Log Egg Production'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            HtmlFormField(label: 'Date', child: HtmlDateTile(date: DateTime.now())),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Total Eggs Collected',
              child: TextField(controller: totalCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 3600')),
            ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Damaged / Cracked Eggs',
              child: TextField(controller: damagedCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 85')),
            ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Laying Hens (for HD%)',
              child: TextField(controller: hensCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 4800')),
            ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Notes',
              child: TextField(controller: notesCtrl, maxLines: 3, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Optional: weather, stress factors...')),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final count   = int.tryParse(totalCtrl.text.trim()) ?? 0;
              if (count <= 0) return;
              final damaged = int.tryParse(damagedCtrl.text.trim()) ?? 0;
              context.read<EggProductionProvider>().addRecord(EggProduction(
                batchId: 'all',
                date: DateTime.now(),
                eggCount: count,
                damagedCount: damaged,
                pricePerEgg: 1.0,
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Egg log saved ✓'),
                backgroundColor: AppColors.green.withValues(alpha: 0.9),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, EggProduction egg, EggProductionProvider provider) {
    final countCtrl   = TextEditingController(text: '${egg.eggCount}');
    final damagedCtrl = TextEditingController(text: '${egg.damagedCount}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Egg Record'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          HtmlFormField(label: 'Number of Eggs', child: TextField(controller: countCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Total eggs'))),
          const SizedBox(height: 12),
          HtmlFormField(label: 'Damaged / Cracked', child: TextField(controller: damagedCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Damaged count'))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final count   = int.tryParse(countCtrl.text) ?? 0;
              final damaged = int.tryParse(damagedCtrl.text) ?? 0;
              if (count <= 0) return;
              provider.updateRecord(egg.copyWith(eggCount: count, damagedCount: damaged));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated ✏️'), backgroundColor: AppColors.cyan, behavior: SnackBarBehavior.floating));
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
