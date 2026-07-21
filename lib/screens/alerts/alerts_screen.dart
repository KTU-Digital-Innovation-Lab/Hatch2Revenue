import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/vaccination.dart';
import '../../providers/batch_provider.dart';
import '../../providers/egg_sales_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/mortality_provider.dart';
import '../../providers/vaccination_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/units.dart';

/// One severity level for an alert row.
enum AlertLevel { critical, warning, info }

class FarmAlert {
  final AlertLevel level;
  final IconData icon;
  final String title;
  final String detail;
  const FarmAlert(this.level, this.icon, this.title, this.detail);

  Color get color => switch (level) {
        AlertLevel.critical => AppColors.red,
        AlertLevel.warning => AppColors.amber,
        AlertLevel.info => AppColors.cyan,
      };
}

/// Everything that needs the farmer's attention, gathered in one place
/// and reachable from the bell in the top-right corner.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  /// Count used for the bell badge — critical + warning items only.
  static int alertCount(BuildContext context) =>
      _collect(context).where((a) => a.level != AlertLevel.info).length;

  static List<FarmAlert> _collect(BuildContext context) {
    final out = <FarmAlert>[];
    final vacc = context.read<VaccinationProvider>();
    final feed = context.read<FeedProvider>();
    final sales = context.read<EggSalesProvider>();
    final mort = context.read<MortalityProvider>();
    final batches = context.read<BatchProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── Vaccinations ────────────────────────────────────────────────
    for (final v in vacc.vaccinations.where((v) => v.isOverdue)) {
      out.add(FarmAlert(
        AlertLevel.critical,
        Icons.vaccines_outlined,
        'Overdue: ${v.vaccineName}',
        'Was due ${DateFormat('d MMM').format(v.scheduledDate)} · '
            '${batches.batchLabel(v.batchId)}',
      ));
    }
    for (final v in vacc.vaccinations.where((v) {
      if (v.status != VaccinationStatus.scheduled || v.isOverdue) return false;
      final d = DateTime(v.scheduledDate.year, v.scheduledDate.month,
          v.scheduledDate.day);
      return d.difference(today).inDays <= 3;
    })) {
      final d = DateTime(
          v.scheduledDate.year, v.scheduledDate.month, v.scheduledDate.day);
      final days = d.difference(today).inDays;
      out.add(FarmAlert(
        AlertLevel.warning,
        Icons.vaccines_outlined,
        v.vaccineName,
        days == 0
            ? 'Due today · ${batches.batchLabel(v.batchId)}'
            : days == 1
                ? 'Due tomorrow · ${batches.batchLabel(v.batchId)}'
                : 'Due in $days days · ${batches.batchLabel(v.batchId)}',
      ));
    }

    // ── Feed ────────────────────────────────────────────────────────
    for (final i in feed.inventory.where((i) => i.isExpired)) {
      out.add(FarmAlert(AlertLevel.critical, Icons.inventory_2_outlined,
          'Expired feed: ${i.feedTypeName}', 'Remove or replace before feeding'));
    }
    for (final i in feed.inventory.where((i) => i.isLowStock && !i.isExpired)) {
      out.add(FarmAlert(AlertLevel.warning, Icons.grass,
          'Low stock: ${i.feedTypeName}',
          '${Units.bagShort(i.quantityKg)} bags left — reorder soon'));
    }

    // ── Money owed ──────────────────────────────────────────────────
    final owed = sales.totalOutstanding;
    if (owed > 0) {
      final debtors = sales.sales.where((s) => !s.isPaid).length;
      out.add(FarmAlert(
        AlertLevel.warning,
        Icons.account_balance_wallet_outlined,
        '${CurrencyFormatter.currencySymbol}${owed.toStringAsFixed(2)} owed to you',
        '$debtors unpaid ${debtors == 1 ? 'sale' : 'sales'} — open Eggs to collect',
      ));
    }

    // ── Mortality this week ─────────────────────────────────────────
    final weekAgo = today.subtract(const Duration(days: 7));
    final weekDeaths = mort.records
        .where((m) => m.date.isAfter(weekAgo))
        .fold(0, (s, m) => s + m.count);
    final birds = batches.totalBirds;
    if (weekDeaths > 0 && birds > 0 && weekDeaths / (birds + weekDeaths) > 0.02) {
      out.add(FarmAlert(AlertLevel.critical, Icons.monitor_heart_outlined,
          '$weekDeaths deaths this week',
          'Above 2% of the flock — inspect the house, consider a vet'));
    }

    if (out.isEmpty) {
      out.add(const FarmAlert(AlertLevel.info, Icons.check_circle_outline,
          'All clear', 'No vaccinations due, feed low, or debts outstanding.'));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // watch so the list refreshes while open
    context.watch<VaccinationProvider>();
    context.watch<FeedProvider>();
    context.watch<EggSalesProvider>();
    final alerts = _collect(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Alerts')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: alerts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final a = alerts[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: a.color.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(a.detail,
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
