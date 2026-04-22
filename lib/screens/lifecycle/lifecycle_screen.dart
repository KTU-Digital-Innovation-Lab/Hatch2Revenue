import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../providers/batch_provider.dart';
import '../../providers/quick_action_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/html_widgets.dart';

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
                title: '🐣 Batch Lifecycle Tracker',
                subtitle: 'Track breed info, entry dates, age in weeks, and stage transitions',
                action: PrimaryBtn(
                  label: '+ Add Batch',
                  onPressed: () => _showAddDialog(context, batchProvider),
                ),
              ),

              KpiCard(label: 'Total Birds', value: '$totalBirds', icon: '🐔', accentColor: AppColors.amber),
              const SizedBox(height: 12),
              KpiCard(label: 'Active Batches', value: '${batches.length}', icon: '🐣', accentColor: AppColors.green),
              const SizedBox(height: 12),
              KpiCard(label: 'In Layer Stage', value: '$layerBirds', icon: '📅', accentColor: AppColors.cyan),
              const SizedBox(height: 12),
              KpiCard(label: 'Avg Age (wks)', value: avgAge, icon: '⏱️', accentColor: AppColors.purple),
              const SizedBox(height: 18),

              HtmlCard(
                header: HtmlCardHeader(
                  title: '📋 All Batches',
                  trailing: TagChip(label: '${batches.length} Batch${batches.length != 1 ? "es" : ""}', color: AppColors.amber),
                ),
                bodyPadding: EdgeInsets.zero,
                body: batches.isEmpty
                    ? HtmlEmptyState(
                        icon: '🐣',
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
        columns: ['BATCH ID', 'BREED / NAME', 'AGE (WKS)', 'STAGE', 'BIRDS', 'ENTRY DATE', '']
            .map((h) => DataColumn(
                  label: Text(h, style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1.5)),
                ))
            .toList(),
        rows: batches.map((b) {
          final stage = _stageName(b.type);
          final stageColor = _stageColor(b.type);
          final ageWks = (b.ageInDays / 7).toStringAsFixed(1);
          return DataRow(cells: [
            DataCell(Text(b.name, style: GoogleFonts.dmMono(color: AppColors.amber, fontWeight: FontWeight.w500, fontSize: 12))),
            DataCell(Text(b.source ?? '—', style: GoogleFonts.dmMono(color: AppColors.textPrimary, fontSize: 12))),
            DataCell(Text('$ageWks wks', style: GoogleFonts.dmMono(color: AppColors.textPrimary, fontSize: 12))),
            DataCell(StagePill(label: stage, color: stageColor)),
            DataCell(Text('${b.currentCount}', style: GoogleFonts.dmMono(color: AppColors.textPrimary, fontSize: 12))),
            DataCell(Text(DateFormat('d MMM yyyy').format(b.hatchDate), style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 11))),
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
    final notesCtrl = TextEditingController();
    BatchType selectedType = BatchType.dayOldChicks;
    DateTime selectedEntryDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('🐣 Add New Batch'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(label: 'Batch ID', child: TextField(controller: idCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. B-2026-01'))),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Breed', child: TextField(controller: breedCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Lohmann Brown'))),
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
              HtmlFormField(label: 'Number of Birds', child: TextField(controller: countCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 2000'))),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Current Stage',
                child: DropdownButtonFormField<BatchType>(
                  value: selectedType,
                  dropdownColor: AppColors.surfaceLight,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: BatchType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(_stageLabel(t), style: const TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedType = v ?? selectedType),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Age at Entry (Weeks)', child: TextField(controller: ageCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 1'))),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Notes', child: TextField(controller: notesCtrl, maxLines: 3, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Optional notes...'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final id    = idCtrl.text.trim();
                final count = int.tryParse(countCtrl.text.trim()) ?? 0;
                if (id.isEmpty || count <= 0) return;
                final ageWks = int.tryParse(ageCtrl.text.trim()) ?? 0;
                final hatchDate = selectedEntryDate.subtract(Duration(days: ageWks * 7));
                provider.addBatch(Batch(
                  name: id,
                  type: selectedType,
                  initialCount: count,
                  currentCount: count,
                  hatchDate: hatchDate,
                  source: breedCtrl.text.trim().isEmpty ? null : breedCtrl.text.trim(),
                  description: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Batch saved ✓'),
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

  void _showEditDialog(BuildContext context, Batch batch) {
    final nameCtrl  = TextEditingController(text: batch.name);
    final countCtrl = TextEditingController(text: '${batch.currentCount}');
    BatchType selectedType = batch.type;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Batch'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(label: 'Batch ID', child: TextField(controller: nameCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Batch ID'))),
              const SizedBox(height: 12),
              HtmlFormField(label: 'Current Bird Count', child: TextField(controller: countCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Count'))),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Stage',
                child: DropdownButtonFormField<BatchType>(
                  value: selectedType,
                  dropdownColor: AppColors.surfaceLight,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: BatchType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(_stageLabel(t), style: const TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedType = v ?? selectedType),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final name  = nameCtrl.text.trim();
                final count = int.tryParse(countCtrl.text) ?? 0;
                if (name.isEmpty || count <= 0) return;
                context.read<BatchProvider>().updateBatch(batch.copyWith(name: name, currentCount: count, type: selectedType));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Batch updated ✏️'),
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

  void _confirmDelete(BuildContext context, Batch batch, BatchProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch'),
        content: Text('Delete "${batch.name}"?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () { provider.deleteBatch(batch.id); Navigator.pop(ctx); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
