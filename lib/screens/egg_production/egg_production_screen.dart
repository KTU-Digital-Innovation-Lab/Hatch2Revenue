import 'package:flutter/material.dart';
import '../../utils/caps.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../models/egg_production.dart';
import '../../models/egg_sale.dart';
import '../../models/financial_transaction.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/egg_sales_provider.dart';
import '../../providers/batch_provider.dart';
import '../../providers/financial_provider.dart';
import '../../providers/quick_action_provider.dart';
import '../../providers/weather_provider.dart';
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
            showAddDialog(context);
          });
        }

        final logs     = eggProvider.records;
        final total    = eggProvider.totalEggs;
        final damaged  = eggProvider.totalDamagedEggs;
        // Store = good eggs collected minus eggs sold (never negative).
        final salesProvider = context.watch<EggSalesProvider>();
        final store = (total - damaged - salesProvider.totalEggsSold)
            .clamp(0, 1 << 30);
        final owed = salesProvider.totalOutstanding;
        // Hen-Day % against birds currently in layer stage (all birds if none).
        final layerBirds = () {
          final layers = batchProvider.batches
              .where((b) => b.currentStage == BatchStage.layer)
              .fold(0, (s, b) => s + b.currentCount);
          return layers > 0 ? layers : batchProvider.totalBirds;
        }();
        double hdPct(int eggs) => layerBirds > 0 ? eggs / layerBirds * 100 : 0;
        final latestHdRaw =
            logs.isNotEmpty && layerBirds > 0 ? hdPct(logs.last.eggCount) : null;
        final latestHdOver = latestHdRaw != null && latestHdRaw > 100.5;
        final latestHd = latestHdRaw != null
            ? '${latestHdRaw.toStringAsFixed(1)}%${latestHdOver ? ' (check)' : ''}'
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
                action: Caps.of(context).canLogEggs
                    ? PrimaryBtn(label: '+ Log Today\'s Eggs', onPressed: () => showAddDialog(context))
                    : null,
              ),

              KpiGrid(children: [
                KpiCard(label: 'In Store', value: Units.crateShort(store), sub: Units.crateLabel(store), accentColor: AppColors.amber),
                // Money owed is hidden from anyone who can't see the books.
                if (Caps.of(context).canSeeMoney)
                  KpiCard(label: 'Owed to You', value: '${CurrencyFormatter.currencySymbol}${owed.toStringAsFixed(0)}', accentColor: owed > 0 ? AppColors.red : AppColors.green),
                KpiCard(label: 'Total Crates', value: Units.crateShort(total), sub: Units.crateLabel(total), accentColor: AppColors.green),
                KpiCard(label: 'Damaged (eggs)', value: '$damaged', accentColor: AppColors.red),
                KpiCard(label: 'HD% (latest)', value: latestHd, accentColor: latestHdOver ? AppColors.red : AppColors.cyan),
                KpiCard(label: 'Days Logged', value: '${logs.length}', accentColor: AppColors.purple),
              ]),
              const SizedBox(height: 18),

              // Weather-aware forecast. Opt-in: nothing is fetched (and no
              // location asked for) until the farmer taps Enable.
              Consumer<WeatherProvider>(builder: (context, wx, _) {
                Widget body;
                if (wx.loading) {
                  body = Row(children: const [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Getting your local weather…'),
                  ]);
                } else if (wx.data == null) {
                  body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      wx.error ??
                          'See how today\'s weather may affect laying. Uses your location to fetch the local forecast.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    PrimaryBtn(
                      label: wx.error != null ? 'Try again' : 'Enable local weather',
                      small: true,
                      onPressed: () => wx.load(),
                    ),
                  ]);
                } else {
                  final d = wx.data!;
                  final risk = d.layingRisk();
                  final rc = (risk == null || risk.level == 'good')
                      ? AppColors.green
                      : (risk.level == 'high' ? AppColors.red : AppColors.amber);
                  body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('${d.tempC.toStringAsFixed(0)}°C',
                          style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Today ${d.todayMinC.toStringAsFixed(0)}° to ${d.todayMaxC.toStringAsFixed(0)}°'
                          '${d.tomorrowMaxC != null ? ' · tomorrow up to ${d.tomorrowMaxC!.toStringAsFixed(0)}°' : ''}'
                          '${d.humidity != null ? ' · ${d.humidity!.toStringAsFixed(0)}% humidity' : ''}',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ]),
                    if (risk != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: rc.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: rc.withValues(alpha: 0.4)),
                        ),
                        child: Text(risk.message,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                                height: 1.4)),
                      ),
                    ],
                  ]);
                }
                return HtmlCard(
                  header: HtmlCardHeader(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Weather & laying',
                    trailing: wx.hasData
                        ? GhostBtn(label: 'Refresh', onPressed: () => wx.load())
                        : null,
                  ),
                  body: body,
                );
              }),
              const SizedBox(height: 18),

              // Selling draws down the store. Everyone who logs eggs can
              // record a sale, but only owner/manager see the debtors
              // ledger and outstanding balances — a worker just records
              // the sale and moves on.
              if (Caps.of(context).canSell || Caps.of(context).canSeeMoney)
                Builder(builder: (context) {
                  final caps = Caps.of(context);
                  return HtmlCard(
                    header: HtmlCardHeader(
                      icon: Icons.point_of_sale_outlined,
                      title: caps.canSeeMoney ? 'Egg Sales & Debtors' : 'Sell Eggs',
                      trailing: caps.canSell
                          ? PrimaryBtn(
                              label: '+ Sell Eggs',
                              small: true,
                              onPressed: () => _showSellDialog(context, store),
                            )
                          : null,
                    ),
                    bodyPadding: EdgeInsets.zero,
                    body: caps.canSeeMoney
                        ? (salesProvider.sales.isEmpty
                            ? const HtmlEmptyState(
                                icon: Icons.point_of_sale_outlined,
                                message:
                                    'No sales yet. Collections fill your store; record a sale when eggs leave the farm.',
                              )
                            : _salesTable(context, salesProvider))
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Record a sale when eggs leave the farm. '
                              'The owner keeps the sales record and tracks who owes.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12.5),
                            ),
                          ),
                  );
                }),

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
                        action: Caps.of(context).canLogEggs ? PrimaryBtn(label: '+ Log Eggs', small: true, onPressed: () => showAddDialog(context)) : null,
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
    final bp = context.read<BatchProvider>();
    return HtmlTable(
      headers: ['Date', 'Batch', 'Time', 'Crates', 'Good', 'Damaged', 'HD%', ''],
      dates: sorted.map((e) => e.date).toList(),
      rows: sorted.map((e) => [
        Text(DateFormat('d MMM yyyy').format(e.date), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Text(bp.batchLabel(e.batchId), style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
        Text(e.period ?? '—', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Text(Units.crateLabel(e.eggCount), style: GoogleFonts.inter(color: AppColors.green, fontWeight: FontWeight.w500, fontSize: 12)),
        Text(Units.crateLabel(e.goodCount), style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
        Text('${e.damagedCount}', style: GoogleFonts.inter(color: e.damagedCount > 0 ? AppColors.red : AppColors.textSecondary, fontSize: 11)),
        _hdCell(hdPct(e.eggCount)),
        Caps.of(context).canAmend
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                EditBtn(onTap: () => _showEditDialog(context, e, provider)),
                DelBtn(onTap: () => provider.removeRecord(e.id)),
              ])
            : const SizedBox.shrink(),
      ]).toList(),
    );
  }

  /// Hen-day percentage cannot exceed 100% (a hen lays at most one egg a
  /// day). A value above that means the entry is off, usually a mistyped
  /// crate count, so it is flagged in the danger colour rather than shown
  /// as if it were a real, very high laying rate.
  Widget _hdCell(double hd) {
    final over = hd > 100.5;
    return Text(
      over ? '${hd.toStringAsFixed(1)}% (check)' : '${hd.toStringAsFixed(1)}%',
      style: GoogleFonts.inter(
        color: over ? AppColors.red : AppColors.textPrimary,
        fontSize: 11,
        fontWeight: over ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }

  /// Opens the egg log. When [presetBatchId] is given (the batch hub
  /// passes it), the flock is fixed and shown locked instead of as a
  /// dropdown, so a collection cannot be filed against the wrong batch.
  static void showAddDialog(BuildContext context, {String? presetBatchId}) {
    final cratesCtrl  = TextEditingController();
    final looseCtrl   = TextEditingController();
    final damagedCtrl = TextEditingController();
    final notesCtrl   = TextEditingController();

    final batches = context.read<BatchProvider>().batches;
    // Records reference batches by ID; 'All' means the whole flock.
    final batchOptions = {'All': 'All', for (final b in batches) b.id: b.name};
    String selectedBatch = presetBatchId ?? 'All';
    DateTime selectedDate = DateTime.now();
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
            if (presetBatchId != null)
              LockedBatchField(
                  batchName: batchOptions[presetBatchId] ?? presetBatchId)
            else
              HtmlFormField(
                label: 'Batch / Flock',
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
              // Collection is production only — income books when the
              // eggs are actually SOLD (Egg Sales & Debtors card).
              context.read<EggProductionProvider>().addRecord(EggProduction(
                batchId: selectedBatch,
                date: selectedDate,
                eggCount: count,
                damagedCount: damaged,
                pricePerEgg: 0,
                period: selectedPeriod,
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              ));

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Egg log saved — eggs added to your store'),
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record updated'), backgroundColor: AppColors.cyan, behavior: SnackBarBehavior.floating));
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // ─── Egg sales & debtors ─────────────────────────────────────────

  Widget _salesTable(BuildContext context, EggSalesProvider provider) {
    final sym = CurrencyFormatter.currencySymbol;
    return HtmlTable(
      headers: ['Date', 'Buyer', 'Crates', 'Total', 'Owed', ''],
      dates: provider.sales.map((s) => s.date).toList(),
      rows: provider.sales.map((s) {
        final buyer = s.buyer.length > 12 ? '${s.buyer.substring(0, 12)}…' : s.buyer;
        return [
          Text(DateFormat('d MMM').format(s.date), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
          Text(buyer, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
          Text(Units.crateShort(s.eggCount), style: GoogleFonts.inter(color: AppColors.green, fontWeight: FontWeight.w500, fontSize: 12)),
          Text('$sym${s.total.toStringAsFixed(0)}', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
          s.isPaid
              ? TagChip(label: 'Paid', color: AppColors.green)
              : Text('$sym${s.owed.toStringAsFixed(0)}', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w600, fontSize: 12)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (!s.isPaid)
              GestureDetector(
                onTap: () => _showPaymentDialog(context, s, provider),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(Icons.payments_outlined, color: AppColors.green, size: 18),
                ),
              ),
            DelBtn(onTap: () => _confirmDeleteSale(context, s, provider)),
          ]),
        ];
      }).toList(),
    );
  }

  void _showSellDialog(BuildContext context, int store) {
    final buyerCtrl  = TextEditingController();
    final cratesCtrl = TextEditingController();
    final looseCtrl  = TextEditingController();
    final priceCtrl  = TextEditingController();
    final paidCtrl   = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final sym = CurrencyFormatter.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final crates = double.tryParse(cratesCtrl.text.trim()) ?? 0;
        final loose  = int.tryParse(looseCtrl.text.trim()) ?? 0;
        final eggs   = (crates * Units.eggsPerCrate).round() + loose;
        final pricePerCrate = double.tryParse(priceCtrl.text.trim()) ?? 0;
        final totalValue = eggs / Units.eggsPerCrate * pricePerCrate;
        return AlertDialog(
          title: const Text('Sell Eggs'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: 'Date',
                child: HtmlDateTile(
                  date: selectedDate,
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) ss(() => selectedDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Buyer',
                child: TextField(controller: buyerCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Maame Ama — blank for cash sale')),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: HtmlFormField(label: 'Crates', child: TextField(controller: cratesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 3'), onChanged: (_) => ss(() {})))),
                const SizedBox(width: 12),
                Expanded(child: HtmlFormField(label: 'Loose Eggs', child: TextField(controller: looseCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('0–29'), onChanged: (_) => ss(() {})))),
              ]),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('In store: ${Units.crateLabel(store)}',
                    style: TextStyle(color: eggs > store ? AppColors.red : AppColors.textSecondary, fontSize: 11)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: HtmlFormField(label: 'Price / Crate ($sym)', child: TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 55'), onChanged: (_) => ss(() {})))),
                const SizedBox(width: 12),
                Expanded(child: HtmlFormField(label: 'Paid Now ($sym)', child: TextField(controller: paidCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('0 = all on credit')))),
              ]),
              if (totalValue > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Total: $sym${totalValue.toStringAsFixed(2)}',
                      style: TextStyle(color: AppColors.amber, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                if (eggs <= 0 || pricePerCrate <= 0) return;
                final paid = (double.tryParse(paidCtrl.text.trim()) ?? 0)
                    .clamp(0.0, eggs / Units.eggsPerCrate * pricePerCrate);
                final buyer = buyerCtrl.text.trim().isEmpty ? 'Cash sale' : buyerCtrl.text.trim();
                final sale = EggSale(
                  date: selectedDate,
                  buyer: buyer,
                  eggCount: eggs,
                  pricePerEgg: pricePerCrate / Units.eggsPerCrate,
                  amountPaid: paid,
                );
                context.read<EggSalesProvider>().addSale(sale);
                // Cash-basis: only money actually received books as income.
                if (paid > 0) {
                  context.read<FinancialProvider>().addTransaction(FinancialTransaction(
                    date: selectedDate,
                    type: TransactionType.income,
                    category: TransactionCategory.eggSales,
                    amount: paid,
                    description: 'Egg sale: ${Units.crateLabel(eggs)} to $buyer',
                    sourceId: sale.id,
                  ));
                }
                Navigator.pop(ctx);
                final owedNow = sale.owed;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(owedNow > 0
                      ? 'Sale recorded — $buyer owes $sym${owedNow.toStringAsFixed(2)}'
                      : 'Sale recorded — paid in full'),
                  backgroundColor: AppColors.green.withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: const Text('Record Sale'),
            ),
          ],
        );
      }),
    );
  }

  void _showPaymentDialog(BuildContext context, EggSale sale, EggSalesProvider provider) {
    final sym = CurrencyFormatter.currencySymbol;
    final amtCtrl = TextEditingController(text: sale.owed.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${sale.buyer} owes $sym${sale.owed.toStringAsFixed(2)} '
                'for ${Units.crateLabel(sale.eggCount)}.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 14),
          HtmlFormField(
            label: 'Amount Received ($sym)',
            child: TextField(controller: amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final amt = (double.tryParse(amtCtrl.text.trim()) ?? 0).clamp(0.0, sale.owed);
              if (amt <= 0) return;
              provider.recordPayment(sale.id, amt);
              context.read<FinancialProvider>().addTransaction(FinancialTransaction(
                date: DateTime.now(),
                type: TransactionType.income,
                category: TransactionCategory.eggSales,
                amount: amt,
                description: 'Egg payment: ${sale.buyer}',
                sourceId: sale.id,
              ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Payment recorded — $sym${amt.toStringAsFixed(2)} from ${sale.buyer}'),
                backgroundColor: AppColors.green.withValues(alpha: 0.9),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('Save Payment'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSale(BuildContext context, EggSale sale, EggSalesProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale?'),
        content: Text(
          'Delete the sale of ${Units.crateLabel(sale.eggCount)} to ${sale.buyer}?\n\n'
          'The eggs return to your store and the income from this sale is '
          'removed from Financials.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.removeSale(sale.id);
              // Full undo: drop the sale's income (and any recorded
              // payments) from the books, per the farmer's setup.
              context.read<FinancialProvider>().removeBySource(sale.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}