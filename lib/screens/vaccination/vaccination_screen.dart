import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/vaccination.dart';
import '../../providers/vaccination_provider.dart';
import '../../providers/batch_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/html_widgets.dart';

class VaccinationScreen extends StatefulWidget {
  const VaccinationScreen({super.key});
  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  String _filter = 'all';

  static const List<String> _routes = [
    'Drinking Water',
    'Eye Drop',
    'Injection',
    'Spray',
    'Wing Stab',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<VaccinationProvider, BatchProvider>(
      builder: (context, vaccProvider, batchProvider, _) {
        final all     = vaccProvider.vaccinations;
        final overdue = all.where((v) => v.isOverdue).toList();
        final pending = all.where((v) => v.status == VaccinationStatus.scheduled && !v.isOverdue).toList();
        final done    = all.where((v) => v.status == VaccinationStatus.completed).toList();
        // Compliance = completed ÷ everything that was due by today
        // (completed + overdue) — the core flock-health KPI.
        final dueToDate = done.length + overdue.length;
        final compliance = dueToDate > 0
            ? '${(done.length / dueToDate * 100).round()}%'
            : '—';

        List<Vaccination> shown;
        switch (_filter) {
          case 'overdue': shown = overdue; break;
          case 'pending': shown = pending; break;
          case 'done':    shown = done;    break;
          default:        shown = all;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.vaccines_outlined,
                title: 'Vaccination Scheduler',
                subtitle: 'Schedule vaccines, log completions, and receive alerts',
                action: PrimaryBtn(label: '+ Schedule Vaccine', onPressed: () => _showAddDialog(context)),
              ),

              if (overdue.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.vaccines_outlined, color: AppColors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${overdue.length} overdue ${overdue.length == 1 ? "vaccination" : "vaccinations"}. '
                        'Overdue vaccines raise disease risk — complete them or adjust the schedule.',
                        style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12),
                      ),
                    ),
                  ]),
                ),

              KpiGrid(children: [
                KpiCard(label: 'Overdue', value: '${overdue.length}', accentColor: AppColors.red),
                KpiCard(label: 'Compliance', value: compliance, accentColor: AppColors.green),
                KpiCard(label: 'Upcoming', value: '${pending.length}', accentColor: AppColors.amber),
                KpiCard(label: 'Completed', value: '${done.length}', accentColor: AppColors.cyan),
              ]),
              const SizedBox(height: 18),

              // Schedule card with filter buttons
              HtmlCard(
                header: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.calendar_month_outlined, color: AppColors.textSecondary, size: 16),
                        const SizedBox(width: 8),
                        Text('Vaccination Schedule', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _filterBtn('All', 'all'),
                        const SizedBox(width: 6),
                        _filterBtn('Overdue', 'overdue'),
                        const SizedBox(width: 6),
                        _filterBtn('Pending', 'pending'),
                        const SizedBox(width: 6),
                        _filterBtn('Done', 'done'),
                      ]),
                    ],
                  ),
                ),
                body: shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No records match this filter.',
                            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      )
                    : Column(children: shown.map((v) => _vaccItem(context, v, vaccProvider)).toList()),
              ),

              // Audit trail
              HtmlCard(
                header: const HtmlCardHeader(icon: Icons.history, title: 'Audit Trail — Completed Logs'),
                bodyPadding: EdgeInsets.zero,
                body: done.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: HtmlEmptyState(icon: Icons.vaccines_outlined, message: 'No completed vaccines yet.'),
                      )
                    : _auditTable(context, done),
              ),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  Widget _filterBtn(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _vaccItem(BuildContext context, Vaccination v, VaccinationProvider provider) {
    final String status = v.status == VaccinationStatus.completed
        ? 'done'
        : v.isOverdue ? 'overdue' : 'pending';
    Color dotColor;
    switch (status) {
      case 'done':     dotColor = AppColors.green; break;
      case 'overdue':  dotColor = AppColors.red;   break;
      default:         dotColor = AppColors.amber;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.vaccineName, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  'Due: ${DateFormat('d MMM yyyy').format(v.scheduledDate)} · ${v.unit ?? v.typeName}',
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
          VaccStatusBadge(status: status),
          if (status != 'done') ...[
            const SizedBox(width: 8),
            GhostBtn(
              label: 'Mark Done',
              small: true,
              onPressed: () {
                provider.markAsCompleted(v.id);
                NotificationService().cancelNotification(v.id.hashCode.abs());
              },
            ),
          ],
          const SizedBox(width: 6),
          EditBtn(onTap: () => _showEditDialog(context, v)),
          const SizedBox(width: 4),
          DelBtn(onTap: () => _confirmDelete(context, v, provider)),
        ],
      ),
    );
  }

  Widget _auditTable(BuildContext context, List<Vaccination> done) {
    final bp = context.read<BatchProvider>();
    return HtmlTable(
      headers: ['Vaccine', 'Batch', 'Completed', 'Route'],
      rows: done.map((v) {
        final label = bp.batchLabel(v.batchId);
        return [
        Text(v.vaccineName, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12)),
        Text(
          label.length > 12 ? '${label.substring(0, 12)}…' : label,
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
        ),
        Text(
          v.administeredDate != null
              ? DateFormat('d MMM yyyy').format(v.administeredDate!)
              : DateFormat('d MMM yyyy').format(v.scheduledDate),
          style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11),
        ),
        TagChip(label: v.unit ?? v.typeName, color: AppColors.teal),
      ];
      }).toList(),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl  = TextEditingController();
    // Records reference batches by ID; 'All' means the whole flock.
    final vaccBatches = context.read<BatchProvider>().batches;
    final batchOptions = {'All': 'All', for (final b in vaccBatches) b.id: b.name};
    String selectedBatch = 'All';
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String selectedRoute = _routes.first;
    bool smsAlert = true;
    VaccinationStatus selectedStatus = VaccinationStatus.scheduled;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Schedule Vaccine'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: 'Vaccine Name',
                child: TextField(controller: nameCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Newcastle Disease')),
              ),
              const SizedBox(height: 12),
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
                label: 'Due Date',
                child: HtmlDateTile(
                  date: selectedDate,
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) ss(() => selectedDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Route of Admin',
                child: DropdownButtonFormField<String>(
                  initialValue: selectedRoute,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: _routes.map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(color: AppColors.textPrimary)))).toList(),
                  onChanged: (v) => ss(() => selectedRoute = v ?? selectedRoute),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Reminder?',
                child: DropdownButtonFormField<bool>(
                  initialValue: smsAlert,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: [
                    DropdownMenuItem(value: true,  child: Text('Yes — remind me the day before', style: TextStyle(color: AppColors.textPrimary))),
                    DropdownMenuItem(value: false, child: Text('No reminder', style: TextStyle(color: AppColors.textPrimary))),
                  ],
                  onChanged: (v) => ss(() => smsAlert = v ?? true),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Status',
                child: DropdownButtonFormField<VaccinationStatus>(
                  initialValue: selectedStatus,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: [
                    DropdownMenuItem(value: VaccinationStatus.scheduled,  child: Text('Pending',   style: TextStyle(color: AppColors.textPrimary))),
                    DropdownMenuItem(value: VaccinationStatus.completed,  child: Text('Completed', style: TextStyle(color: AppColors.textPrimary))),
                  ],
                  onChanged: (v) => ss(() => selectedStatus = v ?? selectedStatus),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Notes',
                child: TextField(controller: notesCtrl, maxLines: 3, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Dosage, brand, observations...')),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final name  = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final vacc = Vaccination(
                  batchId: selectedBatch,
                  vaccineName: name,
                  type: VaccineType.viral,
                  scheduledDate: selectedDate,
                  status: selectedStatus,
                  unit: selectedRoute,
                  reminderEnabled: smsAlert,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                context.read<VaccinationProvider>().addVaccination(vacc);
                if (smsAlert && selectedDate.isAfter(DateTime.now())) {
                  final reminder = selectedDate.subtract(const Duration(days: 1));
                  if (reminder.isAfter(DateTime.now())) {
                    NotificationService().scheduleNotification(
                      id: vacc.id.hashCode.abs(),
                      title: 'Vaccination Reminder',
                      body: '${vacc.vaccineName} is due tomorrow!',
                      scheduledDate: reminder,
                    );
                  }
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Vaccine scheduled'),
                  backgroundColor: AppColors.green.withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Vaccination vacc) {
    final nameCtrl  = TextEditingController(text: vacc.vaccineName);
    final notesCtrl = TextEditingController(text: vacc.notes ?? '');
    final bp = context.read<BatchProvider>();
    // Records reference batches by ID; keep the record's current ref
    // selectable even if its batch was deleted (legacy/name refs too).
    final batchOptions = {
      'All': 'All',
      for (final b in bp.batches) b.id: b.name,
    };
    batchOptions.putIfAbsent(vacc.batchId, () => bp.batchLabel(vacc.batchId));
    String selectedBatch = vacc.batchId;
    DateTime selectedDate = vacc.scheduledDate;
    String selectedRoute = _routes.contains(vacc.unit) ? vacc.unit! : _routes.first;
    VaccinationStatus selectedStatus = vacc.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Vaccine'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: 'Vaccine Name',
                child: TextField(controller: nameCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Vaccine name')),
              ),
              const SizedBox(height: 12),
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
                label: 'Due Date',
                child: HtmlDateTile(
                  date: selectedDate,
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) ss(() => selectedDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Route of Admin',
                child: DropdownButtonFormField<String>(
                  initialValue: selectedRoute,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: _routes.map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(color: AppColors.textPrimary)))).toList(),
                  onChanged: (v) => ss(() => selectedRoute = v ?? selectedRoute),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Status',
                child: DropdownButtonFormField<VaccinationStatus>(
                  initialValue: selectedStatus,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: [
                    DropdownMenuItem(value: VaccinationStatus.scheduled, child: Text('Pending',   style: TextStyle(color: AppColors.textPrimary))),
                    DropdownMenuItem(value: VaccinationStatus.completed, child: Text('Completed', style: TextStyle(color: AppColors.textPrimary))),
                    DropdownMenuItem(value: VaccinationStatus.missed,    child: Text('Missed',    style: TextStyle(color: AppColors.textPrimary))),
                    DropdownMenuItem(value: VaccinationStatus.cancelled, child: Text('Cancelled', style: TextStyle(color: AppColors.textPrimary))),
                  ],
                  onChanged: (v) => ss(() => selectedStatus = v ?? selectedStatus),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Notes',
                child: TextField(controller: notesCtrl, maxLines: 3, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Dosage, brand, observations...')),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final updated = vacc.copyWith(
                  vaccineName: name,
                  batchId: selectedBatch,
                  scheduledDate: selectedDate,
                  unit: selectedRoute,
                  status: selectedStatus,
                  administeredDate: selectedStatus == VaccinationStatus.completed &&
                          vacc.administeredDate == null
                      ? DateTime.now()
                      : null, // null keeps the existing value
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                context.read<VaccinationProvider>().updateVaccination(updated);

                // Refresh the reminder for the new date/status
                NotificationService().cancelNotification(vacc.id.hashCode.abs());
                if (updated.status == VaccinationStatus.scheduled &&
                    updated.reminderEnabled) {
                  final reminder = selectedDate.subtract(const Duration(days: 1));
                  if (reminder.isAfter(DateTime.now())) {
                    NotificationService().scheduleNotification(
                      id: updated.id.hashCode.abs(),
                      title: 'Vaccination Reminder',
                      body: '${updated.vaccineName} is due tomorrow!',
                      scheduledDate: reminder,
                    );
                  }
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Vaccine updated'),
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

  void _confirmDelete(BuildContext context, Vaccination v, VaccinationProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vaccination?'),
        content: Text('Remove "${v.vaccineName}"?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () { provider.removeVaccination(v.id); Navigator.pop(ctx); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}