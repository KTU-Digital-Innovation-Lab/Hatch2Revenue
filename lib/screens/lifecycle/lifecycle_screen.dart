import 'package:flutter/material.dart';
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
import '../../providers/quick_action_provider.dart';
import '../../providers/vaccination_provider.dart';
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
        final layerBirds = batches
            .where((b) => b.type == BatchType.layers)
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
                action: PrimaryBtn(
                  label: '+ Add Batch',
                  onPressed: () => _showAddDialog(context, batchProvider),
                ),
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
                        message: 'No batches yet. Add your first batch.',
                        action: PrimaryBtn(label: '+ Add Batch', small: true, onPressed: () => _showAddDialog(context, batchProvider)),
                      )
                    : _buildTable(context, batches, batchProvider),
              ),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTable(BuildContext context, List<Batch> batches, BatchProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
        columnSpacing: 16,
        headingRowColor: const WidgetStatePropertyAll(Colors.transparent),
        border: TableBorder(
          horizontalInside: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 0.5),
        ),
        columns: ['BATCH ID', 'BREED / NAME', 'AGE (WKS)', 'STAGE', 'BIRDS', 'ENTRY DATE', ' ', '']
            .map((h) => DataColumn(
                  label: Text(h, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1.5)),
                ))
            .toList(),
        rows: batches.map((b) {
          final stage = _stageName(b.type);
          final stageColor = _stageColor(b.type);
          final ageWks = (b.ageInDays / 7).toStringAsFixed(1);
          void openDetail() => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BatchDetailScreen(batchId: b.id),
                ),
              );
          return DataRow(
            onSelectChanged: (_) => openDetail(),
            cells: [
            DataCell(Text(b.name, style: GoogleFonts.inter(color: AppColors.amber, fontWeight: FontWeight.w500, fontSize: 12))),
            DataCell(Text(b.source ?? '—', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12))),
            DataCell(Text('$ageWks wks', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12))),
            DataCell(StagePill(label: stage, color: stageColor)),
            DataCell(Text('${b.currentCount}', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12))),
            DataCell(Text(DateFormat('d MMM yyyy').format(b.hatchDate), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11))),
            DataCell(IconButton(
              tooltip: 'View details',
              icon: Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
              onPressed: openDetail,
            )),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              EditBtn(onTap: () => _showEditDialog(context, b)),
              const SizedBox(width: 4),
              DelBtn(onTap: () => _confirmDelete(context, b, provider)),
            ])),
          ]);
        }).toList(),
      ),
    );
  }

  String _stageName(BatchType t) {
    switch (t) {
      case BatchType.dayOldChicks: return 'Brooding';
      case BatchType.growers:      return 'Grower';
      case BatchType.layers:       return 'Layer';
    }
  }

  String _stageLabel(BatchType t) {
    switch (t) {
      case BatchType.dayOldChicks: return 'Brooding (0-4 wks)';
      case BatchType.growers:      return 'Grower (4-12 wks)';
      case BatchType.layers:       return 'Layer (12+ wks)';
    }
  }

  Color _stageColor(BatchType t) {
    switch (t) {
      case BatchType.dayOldChicks: return AppColors.amber;
      case BatchType.growers:      return AppColors.cyan;
      case BatchType.layers:       return AppColors.green;
    }
  }

  void _showAddDialog(BuildContext context, BatchProvider provider) {
    final idCtrl    = TextEditingController();
    final breedCtrl = TextEditingController();
    final countCtrl = TextEditingController();
    final ageCtrl   = TextEditingController();
    final costCtrl  = TextEditingController();
    final notesCtrl = TextEditingController();
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
                final batch = Batch(
                  name: id,
                  type: selectedType,
                  initialCount: count,
                  currentCount: count,
                  hatchDate: hatchDate,
                  source: breedCtrl.text.trim().isEmpty ? null : breedCtrl.text.trim(),
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
                      category: TransactionCategory.other,
                      amount: cost,
                      batchId: batch.name,
                      description: 'Batch purchase: $id ($count birds)',
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
        batchId: batch.name,
        vaccineName: t.name,
        type: t.type,
        scheduledDate: due,
        notes: t.description,
      ));
    }

    if (vaccinations.isEmpty) return 0;
    context.read<VaccinationProvider>().addAll(vaccinations);

    // Reminders one day before each dose
    for (final v in vaccinations) {
      final reminder = v.scheduledDate.subtract(const Duration(days: 1));
      if (reminder.isAfter(today)) {
        NotificationService().scheduleNotification(
          id: v.id.hashCode.abs(),
          title: 'Vaccination Reminder',
          body: '${v.vaccineName} for ${batch.name} is due tomorrow!',
          scheduledDate: reminder,
        );
      }
    }
    return vaccinations.length;
  }

  void _showEditDialog(BuildContext context, Batch batch) {
    final nameCtrl  = TextEditingController(text: batch.name);
    final breedCtrl = TextEditingController(text: batch.source ?? '');
    final countCtrl = TextEditingController(text: '${batch.currentCount}');
    final notesCtrl = TextEditingController(text: batch.description ?? '');
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
                final oldName = batch.name;
                context.read<BatchProvider>().updateBatch(batch.copyWith(
                  name: name,
                  source: breedCtrl.text.trim().isEmpty ? null : breedCtrl.text.trim(),
                  currentCount: count,
                  type: selectedType,
                  hatchDate: selectedHatchDate,
                  description: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                ));
                // Keep linked records pointing at the renamed batch
                if (name != oldName) {
                  _relinkBatchRecords(context, oldName, name);
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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

  /// After a batch is renamed, updates all records that referenced the
  /// old name so they stay linked (vaccinations, feed, eggs, mortality,
  /// transactions all store the batch name as their ref).
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text(
          'Delete "${batch.name}"?\n\nAll vaccinations, feed logs, egg logs, mortality records and transactions linked to this batch will also be deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () {
              final refs = {batch.id, batch.name};
              context.read<VaccinationProvider>().removeByBatchRefs(refs);
              context.read<FeedProvider>().removeByBatchRefs(refs);
              context.read<EggProductionProvider>().removeByBatchRefs(refs);
              context.read<MortalityProvider>().removeByBatchRefs(refs);
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