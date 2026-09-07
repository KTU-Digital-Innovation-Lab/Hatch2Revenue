import 'package:flutter/material.dart';
import '../../utils/caps.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../models/financial_transaction.dart';
import '../../models/vaccination.dart';
import '../../providers/batch_provider.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/financial_provider.dart';
import '../../providers/mortality_provider.dart';
import '../../providers/measurement_provider.dart';
import '../../providers/quick_action_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vaccination_provider.dart';
import '../../providers/poultry_house_provider.dart';
import '../../models/poultry_house.dart';
import '../../models/measurement.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/html_widgets.dart';
import 'batch_detail_screen.dart';

class LifecycleScreen extends StatelessWidget {
  const LifecycleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BatchProvider, QuickActionProvider>(
      builder: (context, batchProvider, quickActionProvider, _) {
        if (quickActionProvider.action == 'addFlock') {
          quickActionProvider.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAddDialog(context, batchProvider);
          });
        }

        final batches = batchProvider.batches;
        final totalBirds = batches.fold(0, (s, b) => s + b.currentCount);
        // Count by the age-derived stage, not the frozen entry type, so a
        // flock entered as day-old chicks that is now laying is counted.
        final layerBirds = batches
            .where((b) => b.currentStage == BatchStage.layer)
            .fold(0, (s, b) => s + b.currentCount);
        final avgAge = batches.isEmpty
            ? '—'
            : '${(batches.fold(0, (s, b) => s + b.ageInDays) / batches.length / 7).toStringAsFixed(0)}w';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                iconImage: const AssetImage('assets/hen_glyph.png'),
                title: 'Batch Lifecycle Tracker',
                subtitle: 'Track breed info, entry dates, age in weeks, and stage transitions',
                action: Caps.of(context).canAmend
                    ? PrimaryBtn(
                        label: '+ Add Batch',
                        onPressed: () => _showAddDialog(context, batchProvider),
                      )
                    : null,
              ),

              KpiGrid(children: [
                KpiCard(label: 'Total Birds', value: '$totalBirds', accentColor: AppColors.amber),
                KpiCard(label: 'Active Batches', value: '${batches.length}', accentColor: AppColors.green),
                KpiCard(label: 'In Layer Stage', value: '$layerBirds', accentColor: AppColors.cyan),
                KpiCard(label: 'Avg Age (wks)', value: avgAge, accentColor: AppColors.purple),
              ]),
              const SizedBox(height: 18),

              HtmlCard(
                header: HtmlCardHeader(
                  icon: Icons.list_alt_outlined,
                  title: 'All Batches',
                  trailing: TagChip(label: '${batches.length} Batch${batches.length != 1 ? "es" : ""}', color: AppColors.amber),
                ),
                bodyPadding: EdgeInsets.zero,
                body: batches.isEmpty
                    ? HtmlEmptyState(
                        iconImage: const AssetImage('assets/hen_glyph.png'),
                        message: Caps.of(context).canAmend
                            ? 'No batches yet. Add your first batch.'
                            : 'No batches yet. The farm owner sets these up.',
                        action: Caps.of(context).canAmend
                            ? PrimaryBtn(label: '+ Add Batch', small: true, onPressed: () => _showAddDialog(context, batchProvider))
                            : null,
                      )
                    : _buildTable(context, batches, batchProvider),
              ),

              // Houses occupancy — only shown once at least one house
              // exists (house creation stays inline in the add-batch form).
              _housesCard(context, batches),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTable(BuildContext context, List<Batch> batches, BatchProvider provider) {
    final houseProvider = context.watch<PoultryHouseProvider>();
    final measurements = context.watch<MeasurementProvider>();
    // A stacked, tappable card per batch rather than a wide horizontally
    // scrolling table — on a phone the table pushed BIRDS / ENTRY DATE off
    // the right edge. The whole card opens the batch detail.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          for (var i = 0; i < batches.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _batchCard(context, batches[i], provider, houseProvider, measurements),
          ],
        ],
      ),
    );
  }

  Widget _batchCard(BuildContext context, Batch b, BatchProvider provider,
      PoultryHouseProvider houseProvider, MeasurementProvider measurements) {
    // Stage follows the flock's age, not the type it was entered as, so a
    // 24-week day-old-chicks batch reads "Layer", not "Brooding".
    final stage = b.currentStage.label;
    final stageColor = _stageColor(b.currentStage);
    final ageWks = (b.ageInDays / 7).toStringAsFixed(1);
    final houseName = houseProvider.byId(b.coopId)?.name ?? '—';
    void openDetail() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BatchDetailScreen(batchId: b.id)),
        );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openDetail,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      b.name,
                      style: GoogleFonts.inter(color: AppColors.amber, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  StagePill(label: stage, color: stageColor),
                ],
              ),
              const SizedBox(height: 10),
              _kvRow('Breed / name', Text(b.source ?? '—', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12))),
              const SizedBox(height: 6),
              _kvRow('House', Text(houseName, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12))),
              const SizedBox(height: 6),
              _kvRow('Age', Text('$ageWks wks', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12))),
              const SizedBox(height: 6),
              _kvRow('Birds', Text('${b.currentCount}', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12))),
              const SizedBox(height: 6),
              _kvRow('Entry date', Text(DateFormat('d MMM yyyy').format(b.hatchDate), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12))),
              // Surface the latest weight reading right in the list when the
              // farmer has logged one, so flock monitoring isn't invisible.
              if (measurements.latest(b.id, MeasurementType.weight) case final w?) ...[
                const SizedBox(height: 6),
                _kvRow('Latest weight', Text('${w.value == w.value.roundToDouble() ? w.value.toStringAsFixed(0) : w.value.toStringAsFixed(1)} g', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12))),
              ],
              if (Caps.of(context).canAmend) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    EditBtn(onTap: () => _showEditDialog(context, b)),
                    const SizedBox(width: 4),
                    DelBtn(onTap: () => _confirmDelete(context, b, provider)),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kvRow(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 0.5, height: 1.3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
      ],
    );
  }

  String _stageLabel(BatchType t) {
    // Point of lay is 16-22 weeks for day-old chicks; growers cover the
    // pullet window until then.
    switch (t) {
      case BatchType.dayOldChicks: return 'Brooding (0-4 wks)';
      case BatchType.growers:      return 'Grower (4-16 wks)';
      case BatchType.layers:       return 'Layer (from 16-22 wks)';
    }
  }

  Color _stageColor(BatchStage s) {
    switch (s) {
      case BatchStage.brooding: return AppColors.amber;
      case BatchStage.grower:   return AppColors.cyan;
      case BatchStage.layer:    return AppColors.green;
    }
  }

  /// Occupancy overview for the poultry houses. Houses are created inline
  /// in the add-batch form; this restores the ability to SEE how full each
  /// house is and to rename or remove one (edit/delete were create-only
  /// after the standalone Houses screen was dropped). Hidden entirely when
  /// no houses exist so the Batches screen stays clean.
  Widget _housesCard(BuildContext context, List<Batch> batches) {
    final houses = context.watch<PoultryHouseProvider>().houses;
    if (houses.isEmpty) return const SizedBox.shrink();
    final canAmend = Caps.of(context).canAmend;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: HtmlCard(
        header: HtmlCardHeader(
          icon: Icons.home_work_outlined,
          title: 'Poultry Houses',
          trailing: TagChip(
            label: '${houses.length} House${houses.length != 1 ? "s" : ""}',
            color: AppColors.cyan,
          ),
        ),
        bodyPadding: EdgeInsets.zero,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            children: [
              for (var i = 0; i < houses.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _houseTile(context, houses[i], batches, canAmend),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _houseTile(
      BuildContext context, PoultryHouse h, List<Batch> batches, bool canAmend) {
    final assigned = batches.where((b) => b.coopId == h.id).toList();
    final birdsIn = assigned.fold(0, (s, b) => s + b.currentCount);
    final batchCount = assigned.length;
    final hasCap = h.capacity > 0;
    final pct = hasCap ? birdsIn / h.capacity : 0.0;
    final barColor = !hasCap
        ? AppColors.cyan
        : pct > 1.0
            ? AppColors.red
            : pct > 0.9
                ? AppColors.amber
                : AppColors.green;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    if (h.location != null && h.location!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(h.location!,
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hasCap ? '$birdsIn / ${h.capacity}' : '$birdsIn',
                style: GoogleFonts.poppins(
                    color: barColor, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          if (hasCap) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasCap
                      ? '$batchCount batch${batchCount == 1 ? "" : "es"} · ${(pct * 100).toStringAsFixed(0)}% full'
                      : '$batchCount batch${batchCount == 1 ? "" : "es"} · no capacity set',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
              if (canAmend) ...[
                EditBtn(onTap: () => _showEditHouseDialog(context, h)),
                const SizedBox(width: 4),
                DelBtn(onTap: () => _confirmDeleteHouse(context, h, batchCount)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showEditHouseDialog(BuildContext context, PoultryHouse h) {
    final nameCtrl = TextEditingController(text: h.name);
    final capCtrl = TextEditingController(text: h.capacity > 0 ? '${h.capacity}' : '');
    final locCtrl = TextEditingController(text: h.location ?? '');
    final provider = context.read<PoultryHouseProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit House'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            HtmlFormField(
                label: 'House name',
                child: TextField(controller: nameCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. House 1'))),
            const SizedBox(height: 12),
            HtmlFormField(
                label: 'Capacity (birds) — optional',
                child: TextField(controller: capCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 5000'))),
            const SizedBox(height: 12),
            HtmlFormField(
                label: 'Location — optional',
                child: TextField(controller: locCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. North block'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              provider.updateHouse(h.copyWith(
                name: name,
                capacity: int.tryParse(capCtrl.text.trim()) ?? 0,
                location: locCtrl.text.trim(),
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteHouse(BuildContext context, PoultryHouse h, int assignedCount) {
    final provider = context.read<PoultryHouseProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete House'),
        content: Text(
          assignedCount > 0
              ? 'Delete "${h.name}"? $assignedCount batch${assignedCount == 1 ? "" : "es"} assigned to it will show no house.'
              : 'Delete "${h.name}"?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              provider.removeHouse(h.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, BatchProvider provider) {
    final idCtrl    = TextEditingController();
    final breedCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    final countCtrl = TextEditingController();
    final ageCtrl   = TextEditingController();
    final costCtrl  = TextEditingController();
    final notesCtrl = TextEditingController();
    final newHouseCtrl = TextEditingController();
    const kNewHouse = '__new_house__';
    final houses = context.read<PoultryHouseProvider>().houses;
    String? selectedHouseId;
    BatchType selectedType = BatchType.dayOldChicks;
    DateTime selectedEntryDate = DateTime.now();
    bool autoVacc = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Add New Batch'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(label: 'Batch ID', child: TextField(controller: idCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. B-2026-01'))),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Breed', child: TextField(controller: breedCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Lohmann Brown'))),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Source of Chicks', child: TextField(controller: sourceCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Akate Farms hatchery'))),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'House — optional',
                child: DropdownButtonFormField<String?>(
                  initialValue: selectedHouseId,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('No house', style: TextStyle(color: AppColors.textPrimary))),
                    ...houses.map((h) => DropdownMenuItem<String?>(value: h.id, child: Text(h.name, style: TextStyle(color: AppColors.textPrimary)))),
                    DropdownMenuItem<String?>(value: kNewHouse, child: Text('+ Add a new house', style: TextStyle(color: AppColors.amber))),
                  ],
                  onChanged: (v) => ss(() => selectedHouseId = v),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedHouseId == kNewHouse) ...[
                HtmlFormField(
                  label: 'New house name',
                  child: TextField(controller: newHouseCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. House 1')),
                ),
                const SizedBox(height: 12),
              ],
              HtmlFormField(
                label: 'Entry Date',
                child: HtmlDateTile(
                  date: selectedEntryDate,
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedEntryDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)));
                    if (d != null) ss(() => selectedEntryDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Number of Birds', child: TextField(controller: countCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 2000'))),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Current Stage',
                child: DropdownButtonFormField<BatchType>(
                  initialValue: selectedType,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: BatchType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(_stageLabel(t), style: TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedType = v ?? selectedType),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Age at Entry (Weeks)', child: TextField(controller: ageCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 1'))),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Purchase Cost (${CurrencyFormatter.currencySymbol}) — optional',
                child: TextField(controller: costCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Total cost — auto-logged as expense')),
              ),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Notes', child: TextField(controller: notesCtrl, maxLines: 3, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Optional notes...'))),
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: autoVacc,
                    activeColor: AppColors.amber,
                    checkColor: Colors.black,
                    onChanged: (v) => ss(() => autoVacc = v ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Auto-generate vaccination schedule',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final id    = idCtrl.text.trim();
                final count = int.tryParse(countCtrl.text.trim()) ?? 0;
                if (id.isEmpty || count <= 0) return;
                final ageWks = int.tryParse(ageCtrl.text.trim()) ?? 0;
                final cost   = double.tryParse(costCtrl.text.trim()) ?? 0;
                final hatchDate = selectedEntryDate.subtract(Duration(days: ageWks * 7));
                // Create the house inline when the farmer typed a new one.
                String? coopId = selectedHouseId == kNewHouse ? null : selectedHouseId;
                if (selectedHouseId == kNewHouse && newHouseCtrl.text.trim().isNotEmpty) {
                  final h = PoultryHouse(name: newHouseCtrl.text.trim());
                  context.read<PoultryHouseProvider>().addHouse(h);
                  coopId = h.id;
                }
                final batch = Batch(
                  name: id,
                  type: selectedType,
                  initialCount: count,
                  currentCount: count,
                  hatchDate: hatchDate,
                  source: breedCtrl.text.trim().isEmpty ? null : breedCtrl.text.trim(),
                  supplier: sourceCtrl.text.trim().isEmpty ? null : sourceCtrl.text.trim(),
                  coopId: coopId,
                  initialCost: cost > 0 ? cost : null,
                  description: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                provider.addBatch(batch);

                // Auto-post purchase cost to Financials
                if (cost > 0) {
                  context.read<FinancialProvider>().addTransaction(
                    FinancialTransaction(
                      date: selectedEntryDate,
                      type: TransactionType.expense,
                      category: TransactionCategory.birdPurchase,
                      amount: cost,
                      batchId: batch.id,
                      description: 'Batch purchase: $id ($count birds)',
                      sourceId: batch.id,
                    ),
                  );
                }

                // Auto-generate standard vaccination schedule
                var scheduled = 0;
                if (autoVacc) {
                  scheduled = _generateVaccinationSchedule(context, batch);
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(scheduled > 0
                      ? 'Batch saved · $scheduled vaccinations scheduled'
                      : 'Batch saved'),
                  backgroundColor: AppColors.green.withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: const Text('Save Batch'),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates scheduled vaccinations from the standard template for every
  /// dose that is still in the future given the batch's age.
  /// Returns how many were scheduled.
  int _generateVaccinationSchedule(BuildContext context, Batch batch) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final vaccinations = <Vaccination>[];

    for (final t in VaccinationTemplate.templates) {
      final due = batch.hatchDate.add(Duration(days: t.dayOfAge));
      if (due.isBefore(startOfToday)) continue; // bird already past this age
      vaccinations.add(Vaccination(
        batchId: batch.id,
        vaccineName: t.name,
        type: t.type,
        scheduledDate: due,
        notes: t.description,
      ));
    }

    if (vaccinations.isEmpty) return 0;
    context.read<VaccinationProvider>().addAll(vaccinations);

    // Two reminders per dose: the day before at the farmer's chosen
    // hour, and again at 06:30 on the morning it is due.
    final hour = context.read<SettingsProvider>().reminderHour;
    for (final v in vaccinations) {
      NotificationService().scheduleVaccinationReminders(
        vaccinationId: v.id,
        vaccineName: v.vaccineName,
        batchLabel: batch.name,
        dueDate: v.scheduledDate,
        dayBeforeHour: hour,
      );
    }
    return vaccinations.length;
  }

  void _showEditDialog(BuildContext context, Batch batch) {
    final nameCtrl  = TextEditingController(text: batch.name);
    final breedCtrl = TextEditingController(text: batch.source ?? '');
    final sourceCtrl = TextEditingController(text: batch.supplier ?? '');
    final countCtrl = TextEditingController(text: '${batch.currentCount}');
    final costCtrl  = TextEditingController(
        text: (batch.initialCost ?? 0) > 0 ? batch.initialCost!.toStringAsFixed(0) : '');
    final notesCtrl = TextEditingController(text: batch.description ?? '');
    final newHouseCtrl = TextEditingController();
    const kNewHouse = '__new_house__';
    final houses = context.read<PoultryHouseProvider>().houses;
    // Guard: a coopId pointing at a deleted house would break the dropdown.
    String? selectedHouseId =
        houses.any((h) => h.id == batch.coopId) ? batch.coopId : null;
    BatchType selectedType = batch.type;
    DateTime selectedHatchDate = batch.hatchDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Batch'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(label: 'Batch ID', child: TextField(controller: nameCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Batch ID'))),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Breed', child: TextField(controller: breedCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Lohmann Brown'))),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Source of Chicks', child: TextField(controller: sourceCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Akate Farms hatchery'))),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'House',
                child: DropdownButtonFormField<String?>(
                  initialValue: selectedHouseId,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('No house', style: TextStyle(color: AppColors.textPrimary))),
                    ...houses.map((h) => DropdownMenuItem<String?>(value: h.id, child: Text(h.name, style: TextStyle(color: AppColors.textPrimary)))),
                    DropdownMenuItem<String?>(value: kNewHouse, child: Text('+ Add a new house', style: TextStyle(color: AppColors.amber))),
                  ],
                  onChanged: (v) => ss(() => selectedHouseId = v),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedHouseId == kNewHouse) ...[
                HtmlFormField(
                  label: 'New house name',
                  child: TextField(controller: newHouseCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. House 1')),
                ),
                const SizedBox(height: 12),
              ],
              HtmlFormField(
                label: 'Hatch Date (drives age)',
                child: HtmlDateTile(
                  date: selectedHatchDate,
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedHatchDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) ss(() => selectedHatchDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Current Bird Count', child: TextField(controller: countCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Count'))),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Purchase Cost (${CurrencyFormatter.currencySymbol}) — optional',
                child: TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Auto-logged as Bird Purchase expense')),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Stage',
                child: DropdownButtonFormField<BatchType>(
                  initialValue: selectedType,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: BatchType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(_stageLabel(t), style: TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedType = v ?? selectedType),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Notes', child: TextField(controller: notesCtrl, maxLines: 3, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Optional notes...'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final name  = nameCtrl.text.trim();
                final count = int.tryParse(countCtrl.text) ?? 0;
                if (name.isEmpty || count <= 0) return;
                final cost  = double.tryParse(costCtrl.text.trim()) ?? 0;
                final oldName = batch.name;
                // Create the house inline when the farmer typed a new one.
                String? coopId = selectedHouseId == kNewHouse ? null : selectedHouseId;
                if (selectedHouseId == kNewHouse && newHouseCtrl.text.trim().isNotEmpty) {
                  final h = PoultryHouse(name: newHouseCtrl.text.trim());
                  context.read<PoultryHouseProvider>().addHouse(h);
                  coopId = h.id;
                }
                context.read<BatchProvider>().updateBatch(batch.copyWith(
                  name: name,
                  source: breedCtrl.text.trim().isEmpty ? null : breedCtrl.text.trim(),
                  supplier: sourceCtrl.text.trim().isEmpty ? null : sourceCtrl.text.trim(),
                  coopId: coopId,
                  currentCount: count,
                  type: selectedType,
                  hatchDate: selectedHatchDate,
                  initialCost: cost, // 0 = no cost
                  description: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                ));
                // Upgrade any legacy name-keyed records to the batch id
                if (name != oldName) {
                  _relinkBatchRecords(context, oldName, batch.id);
                }
                // Mirror the purchase cost into Financials: one Bird
                // Purchase expense per batch, updated (or removed) to
                // match whatever the owner typed here.
                final fin = context.read<FinancialProvider>();
                final refs = {batch.id, oldName, name};
                final purchases = fin.transactions
                    .where((t) =>
                        refs.contains(t.batchId) &&
                        (t.category == TransactionCategory.birdPurchase ||
                            (t.description ?? '').startsWith('Batch purchase:')))
                    .toList();
                if (cost > 0) {
                  final desc = 'Batch purchase: $name ($count birds)';
                  if (purchases.isEmpty) {
                    fin.addTransaction(FinancialTransaction(
                      date: DateTime.now(),
                      type: TransactionType.expense,
                      category: TransactionCategory.birdPurchase,
                      amount: cost,
                      batchId: batch.id,
                      description: desc,
                    ));
                  } else if (purchases.first.amount != cost ||
                      purchases.first.batchId != batch.id) {
                    fin.updateTransaction(purchases.first.copyWith(
                      amount: cost,
                      batchId: batch.id,
                      category: TransactionCategory.birdPurchase,
                      description: desc,
                    ));
                  }
                } else {
                  for (final t in purchases) {
                    fin.removeTransaction(t.id);
                  }
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Batch updated'),
                  backgroundColor: AppColors.cyan,
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  /// Records reference batches by ID, so renames need no relinking —
  /// except LEGACY rows (from app versions that stored the batch name),
  /// which this upgrades to the batch id whenever the name changes.
  void _relinkBatchRecords(BuildContext context, String oldName, String newName) {
    final vaccProvider = context.read<VaccinationProvider>();
    for (final v in vaccProvider.getVaccinationsForBatch(oldName)) {
      vaccProvider.updateVaccination(v.copyWith(batchId: newName));
    }
    final feedProvider = context.read<FeedProvider>();
    for (final r in feedProvider.getRecordsForBatch(oldName)) {
      feedProvider.updateRecord(r.copyWith(batchId: newName));
    }
    final eggProvider = context.read<EggProductionProvider>();
    for (final r in eggProvider.getRecordsForBatch(oldName)) {
      eggProvider.updateRecord(r.copyWith(batchId: newName));
    }
    final mortProvider = context.read<MortalityProvider>();
    for (final r in mortProvider.getRecordsForBatch(oldName)) {
      mortProvider.updateRecord(r.copyWith(batchId: newName));
    }
    final finProvider = context.read<FinancialProvider>();
    for (final t in finProvider.getTransactionsForBatch(oldName)) {
      finProvider.updateTransaction(t.copyWith(batchId: newName));
    }
  }

  void _confirmDelete(BuildContext context, Batch batch, BatchProvider provider) {
    // Itemise the blast radius so the owner confirms with full knowledge
    // of exactly what goes with the batch.
    final refs = {batch.id, batch.name};
    String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final eggs = context.read<EggProductionProvider>().records.where((r) => refs.contains(r.batchId)).length;
    final feed = context.read<FeedProvider>().records.where((r) => refs.contains(r.batchId)).length;
    final vacc = context.read<VaccinationProvider>().vaccinations.where((v) => refs.contains(v.batchId)).length;
    final mort = context.read<MortalityProvider>().records.where((r) => refs.contains(r.batchId)).length;
    final txns = context.read<FinancialProvider>().transactions.where((t) => refs.contains(t.batchId)).length;
    final parts = <String>[
      if (eggs > 0) plural(eggs, 'egg log', 'egg logs'),
      if (feed > 0) plural(feed, 'feed log', 'feed logs'),
      if (vacc > 0) plural(vacc, 'vaccination', 'vaccinations'),
      if (mort > 0) plural(mort, 'mortality record', 'mortality records'),
      if (txns > 0) plural(txns, 'transaction', 'transactions'),
    ];
    final detail = parts.isEmpty
        ? 'No other records are linked to this batch.'
        : 'This will ALSO permanently delete:\n•  ${parts.join('\n•  ')}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: Text(
          'Delete "${batch.name}" (${batch.currentCount} birds)?\n\n$detail',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () {
              context.read<VaccinationProvider>().removeByBatchRefs(refs);
              context.read<FeedProvider>().removeByBatchRefs(refs);
              context.read<EggProductionProvider>().removeByBatchRefs(refs);
              context.read<MortalityProvider>().removeByBatchRefs(refs);
              context.read<MeasurementProvider>().removeByBatchRefs(refs);
              context.read<FinancialProvider>().removeByBatchRefs(refs);
              provider.deleteBatch(batch.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}