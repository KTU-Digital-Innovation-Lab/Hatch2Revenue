import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../models/egg_production.dart';
import '../../models/financial_transaction.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/batch_provider.dart';
import '../../providers/financial_provider.dart';
import '../../providers/quick_action_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/html_widgets.dart';
import '../../utils/units.dart';

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
        // Hen-Day % against birds currently in layer stage (all birds if none).
        final layerBirds = () {
          final layers = batchProvider.batches
              .where((b) => b.type == BatchType.layers)
              .fold(0, (s, b) => s + b.currentCount);
          return layers > 0 ? layers : batchProvider.totalBirds;
        }();
        double hdPct(int eggs) => layerBirds > 0 ? eggs / layerBirds * 100 : 0;
        final latestHd = logs.isNotEmpty && layerBirds > 0
            ? '${hdPct(logs.last.eggCount).toStringAsFixed(1)}%'
            : '—%';
        final avgPerDay = eggProvider.averagePerDay;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.egg_outlined,
                title: 'Egg Production Tracker',
                subtitle: 'Production is tracked in crates (30 eggs = 1 crate)',
                action: PrimaryBtn(label: '+ Log Today\'s Eggs', onPressed: () => _showAddDialog(context)),
              ),

              KpiGrid(children: [
                KpiCard(label: 'Total Crates', value: Units.crateShort(total), sub: Units.crateLabel(total), accentColor: AppColors.green),
                KpiCard(label: 'Damaged (eggs)', value: '$damaged', accentColor: AppColors.red),
                KpiCard(label: 'HD% (latest)', value: latestHd, accentColor: AppColors.amber),
                KpiCard(label: 'Days Logged', value: '${logs.length}', accentColor: AppColors.cyan),
              ]),
              const SizedBox(height: 18),

              HtmlCard(
                header: HtmlCardHeader(
                  icon: Icons.calendar_month_outlined,
                  title: 'Monthly Production Calendar',
                  trailing: TagChip(label: _monthLabel(), color: AppColors.green),
                ),
                body: Column(
                  children: [
                    _buildCalendar(logs, avgPerDay),
                    const SizedBox(height: 10),
                    Row(children: [
                      _legend('High',    AppColors.green),
                      const SizedBox(width: 12),
                      _legend('Average', AppColors.amber),
                      const SizedBox(width: 12),
                      _legend('Low',     AppColors.red),
                      const SizedBox(width: 12),
                      _legend('No data', AppColors.textMuted),
                    ]),
                  ],
                ),
              ),

              HtmlCard(
                header: const HtmlCardHeader(icon: Icons.list_alt_outlined, title: 'All Egg Logs'),
                bodyPadding: EdgeInsets.zero,
                body: logs.isEmpty
                    ? HtmlEmptyState(
                        icon: Icons.egg_outlined,
                        message: 'No egg records yet.',
                        action: PrimaryBtn(label: '+ Log Eggs', small: true, onPressed: () => _showAddDialog(context)),
                      )
                    : _logsTable(context, logs, eggProvider, hdPct),
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

  Widget _legend(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: GoogleFonts.inter(color: color, fontSize: 9)),
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
      // Cells read in crates to match the rest of the screen.
      final numLabel = Units.crateShort(e.eggCount);
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
        Text(day, style: GoogleFonts.inter(color: fg, fontSize: 8)),
        if (num.isNotEmpty)
          Text(num, style: GoogleFonts.poppins(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _logsTable(BuildContext context, List<EggProduction> logs, EggProductionProvider provider, double Function(int) hdPct) {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    return HtmlTable(
      headers: ['Date', 'Batch', 'Time', 'Crates', 'Good', 'Damaged', 'HD%', ''],
      rows: sorted.map((e) => [
        Text(DateFormat('d MMM yyyy').format(e.date), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Text(e.batchId, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
        Text(e.period ?? '—', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Text(Units.crateLabel(e.eggCount), style: GoogleFonts.inter(color: AppColors.green, fontWeight: FontWeight.w500, fontSize: 12)),
        Text(Units.crateLabel(e.goodCount), style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
        Text('${e.damagedCount}', style: GoogleFonts.inter(color: e.damagedCount > 0 ? AppColors.red : AppColors.textSecondary, fontSize: 11)),
        Text('${hdPct(e.eggCount).toStringAsFixed(1)}%', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          EditBtn(onTap: () => _showEditDialog(context, e, provider)),
          DelBtn(onTap: () => provider.removeRecord(e.id)),
        ]),
      ]).toList(),
    );
  }

  void _showAddDialog(BuildContext context) {
    final cratesCtrl  = TextEditingController();
    final looseCtrl   = TextEditingController();
    final damagedCtrl = TextEditingController();
    final priceCtrl   = TextEditingController();
    final notesCtrl   = TextEditingController();

    final batches = context.read<BatchProvider>().batches;
    final batchOptions = ['All', ...batches.map((b) => b.name)];
    String selectedBatch = batchOptions.first;
    // Default the period from the time of day, the way field workers
    // log collections (morning/afternoon/evening rounds).
    const periods = ['Morning', 'Afternoon', 'Evening'];
    String selectedPeriod = () {
      final h = DateTime.now().hour;
      if (h < 12) return 'Morning';
      if (h < 16) return 'Afternoon';
      return 'Evening';
    }();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
        // Live production rate against the selected flock's birds.
        final bp = context.read<BatchProvider>();
        final birds = selectedBatch == 'All'
            ? bp.totalBirds
            : (bp.getBatchByRef(selectedBatch)?.currentCount ?? 0);
        final typedCrates = double.tryParse(cratesCtrl.text.trim()) ?? 0;
        final typedLoose = int.tryParse(looseCtrl.text.trim()) ?? 0;
        final typedCount =
            (typedCrates * Units.eggsPerCrate).round() + typedLoose;
        final prodRate = birds > 0 ? typedCount / birds * 100 : 0.0;
        return AlertDialog(
        title: const Text('Log Egg Production'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            HtmlFormField(label: 'Date', child: HtmlDateTile(date: DateTime.now())),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Batch / Flock',
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
              label: 'Collection Time',
              child: Row(
                children: periods.map((p) {
                  final sel = p == selectedPeriod;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => ss(() => selectedPeriod = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? AppColors.amber.withValues(alpha: 0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sel ? AppColors.amber : AppColors.border),
                          ),
                          child: Text(p, style: TextStyle(
                            color: sel ? AppColors.amber : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          )),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: HtmlFormField(
                  label: 'Crates Collected',
                  child: TextField(controller: cratesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 120'), onChanged: (_) => ss(() {})),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HtmlFormField(
                  label: 'Loose Eggs',
                  child: TextField(controller: looseCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('0–29'), onChanged: (_) => ss(() {})),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            if (typedCount > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('= ${Units.crateLabel(typedCount)}  ($typedCount eggs)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Damaged / Cracked Eggs',
              child: TextField(controller: damagedCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 85')),
            ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Price per Crate (${CurrencyFormatter.currencySymbol}) — optional',
              child: TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Sale value auto-logged as income')),
            ),
            const SizedBox(height: 12),
            if (birds > 0 && typedCount > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Production rate: ${prodRate.toStringAsFixed(0)}%  ·  $birds birds',
                  style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            HtmlFormField(
              label: 'Notes',
              child: TextField(controller: notesCtrl, maxLines: 3, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Optional: weather, stress factors...')),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final crates = double.tryParse(cratesCtrl.text.trim()) ?? 0;
              final loose  = int.tryParse(looseCtrl.text.trim()) ?? 0;
              final count  = (crates * Units.eggsPerCrate).round() + loose;
              if (count <= 0) return;
              final damaged = int.tryParse(damagedCtrl.text.trim()) ?? 0;
              // Price entered per crate; store per egg so revenue math
              // (count × pricePerEgg) stays correct.
              final pricePerCrate = double.tryParse(priceCtrl.text.trim()) ?? 0;
              final price = pricePerCrate / Units.eggsPerCrate;
              context.read<EggProductionProvider>().addRecord(EggProduction(
                batchId: selectedBatch,
                date: DateTime.now(),
                eggCount: count,
                damagedCount: damaged,
                pricePerEgg: price,
                period: selectedPeriod,
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              ));

              // Auto-post the sale value to Financials
              final saleValue = (count - damaged) * price;
              if (saleValue > 0) {
                context.read<FinancialProvider>().addTransaction(
                  FinancialTransaction(
                    date: DateTime.now(),
                    type: TransactionType.income,
                    category: TransactionCategory.eggSales,
                    amount: saleValue,
                    description: 'Egg sales: ${Units.crateLabel(count - damaged)} @ ${CurrencyFormatter.currencySymbol}${pricePerCrate.toStringAsFixed(0)}/crate',
                  ),
                );
              }

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(saleValue > 0
                    ? 'Egg log saved — income posted to Financials'
                    : 'Egg log saved'),
                backgroundColor: AppColors.green.withValues(alpha: 0.9),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('Save'),
          ),
        ],
      );
      },
      ),
    );
  }

  void _showEditDialog(BuildContext context, EggProduction egg, EggProductionProvider provider) {
    final cratesCtrl  = TextEditingController(text: '${egg.eggCount ~/ Units.eggsPerCrate}');
    final looseCtrl   = TextEditingController(text: '${egg.eggCount % Units.eggsPerCrate}');
    final damagedCtrl = TextEditingController(text: '${egg.damagedCount}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Egg Record'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: HtmlFormField(label: 'Crates Collected', child: TextField(controller: cratesCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Crates')))),
            const SizedBox(width: 12),
            Expanded(child: HtmlFormField(label: 'Loose Eggs', child: TextField(controller: looseCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('0–29')))),
          ]),
          const SizedBox(height: 12),
          HtmlFormField(label: 'Damaged / Cracked (eggs)', child: TextField(controller: damagedCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Damaged count'))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final crates  = int.tryParse(cratesCtrl.text) ?? 0;
              final loose   = int.tryParse(looseCtrl.text) ?? 0;
              final count   = crates * Units.eggsPerCrate + loose;
              final damaged = int.tryParse(damagedCtrl.text) ?? 0;
              if (count <= 0) return;
              provider.updateRecord(egg.copyWith(eggCount: count, damagedCount: damaged));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated'), backgroundColor: AppColors.cyan, behavior: SnackBarBehavior.floating));
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}