import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/farm_profile_provider.dart';
import '../models/vaccination.dart';
import '../services/insights_engine.dart';
import '../providers/batch_provider.dart';
import '../providers/vaccination_provider.dart';
import '../providers/egg_production_provider.dart';
import '../providers/mortality_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/feed_provider.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../app.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final farmProfile = context.watch<FarmProfileProvider>().profile;
    final batchProvider = context.watch<BatchProvider>();
    final vaccProvider = context.watch<VaccinationProvider>();
    final eggProvider = context.watch<EggProductionProvider>();
    final mortalityProvider = context.watch<MortalityProvider>();
    final financialProvider = context.watch<FinancialProvider>();
    final feedProvider = context.watch<FeedProvider>();

    final farmName = farmProfile.farmName.isNotEmpty ? farmProfile.farmName : 'Hatch2Revenue';
    final netProfit = financialProvider.netProfit;
    final feedKg = feedProvider.totalFeedConsumed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner — matches HTML .dash-welcome
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.amber.withValues(alpha: 0.10),
                  AppColors.cyan.withValues(alpha: 0.07),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome to $farmName. Select a module below to manage your flock.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Live stats — today at a glance
          LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth < 400 ? 2 : 4;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.9,
              children: [
                _StatCard(
                  label: 'BIRDS ALIVE',
                  value: '${batchProvider.totalBirds}',
                  color: AppColors.amber,
                ),
                _StatCard(
                  label: "TODAY'S EGGS",
                  value: '${eggProvider.todayCount}',
                  color: AppColors.green,
                ),
                _StatCard(
                  label: 'OVERDUE VACC.',
                  value: '${vaccProvider.overdueCount}',
                  color: vaccProvider.overdueCount > 0
                      ? AppColors.red
                      : AppColors.cyan,
                ),
                _StatCard(
                  label: 'NET PROFIT',
                  value:
                      '${CurrencyFormatter.currencySymbol}${netProfit.toStringAsFixed(0)}',
                  color: netProfit >= 0 ? AppColors.cyan : AppColors.red,
                ),
              ],
            );
          }),
          const SizedBox(height: 16),

          _PerformanceScoreCard(
            batches: batchProvider,
            eggs: eggProvider,
            vacc: vaccProvider,
          ),
          const SizedBox(height: 16),

          _IntelligencePanel(
            batches: batchProvider,
            eggs: eggProvider,
            feed: feedProvider,
            mortality: mortalityProvider,
            vacc: vaccProvider,
          ),
          const SizedBox(height: 20),

          // Nav grid — matches HTML .dash-nav-grid (3 columns)
          LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth < 400 ? 2 : 3;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                _NavCard(
                  icon: Icons.timeline,
                  color: AppColors.amber,
                  title: 'Batch Lifecycle',
                  sub: '${batchProvider.batches.length} active batch${batchProvider.batches.length != 1 ? "es" : ""}',
                  onTap: () => MainNavigation.navigateTo(context, 1),
                ),
                _NavCard(
                  icon: Icons.vaccines_outlined,
                  color: AppColors.purple,
                  title: 'Vaccination',
                  sub: '${vaccProvider.scheduledCount} scheduled',
                  onTap: () => MainNavigation.navigateTo(context, 2),
                ),
                _NavCard(
                  icon: Icons.grass,
                  color: AppColors.green,
                  title: 'Feed Monitor',
                  sub: feedKg > 0 ? '${feedKg.toStringAsFixed(0)}kg consumed' : 'No feed data',
                  onTap: () => MainNavigation.navigateTo(context, 3),
                ),
                _NavCard(
                  icon: Icons.egg_outlined,
                  color: AppColors.cyan,
                  title: 'Egg Production',
                  sub: '${eggProvider.totalEggs} total eggs',
                  onTap: () => MainNavigation.navigateTo(context, 4),
                ),
                _NavCard(
                  icon: Icons.monitor_heart_outlined,
                  color: AppColors.red,
                  title: 'Mortality Log',
                  sub: '${mortalityProvider.records.length} records',
                  onTap: () => MainNavigation.navigateTo(context, 5),
                ),
                _NavCard(
                  icon: Icons.payments_outlined,
                  color: AppColors.blue,
                  title: 'Financials',
                  sub: financialProvider.transactions.isNotEmpty
                      ? 'Net: ${CurrencyFormatter.currencySymbol}${netProfit.toStringAsFixed(0)}'
                      : 'No transactions',
                  onTap: () => MainNavigation.navigateTo(context, 6),
                ),
              ],
            );
          }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Farm Intelligence — rule-based insight cards + a 7-day egg forecast,
/// computed offline from the farm's own records.
class _IntelligencePanel extends StatelessWidget {
  const _IntelligencePanel({
    required this.batches,
    required this.eggs,
    required this.feed,
    required this.mortality,
    required this.vacc,
  });

  final BatchProvider batches;
  final EggProductionProvider eggs;
  final FeedProvider feed;
  final MortalityProvider mortality;
  final VaccinationProvider vacc;

  Color _color(InsightLevel l) => switch (l) {
        InsightLevel.critical => AppColors.red,
        InsightLevel.warn => AppColors.red,
        InsightLevel.watch => AppColors.amber,
        InsightLevel.info => AppColors.cyan,
        InsightLevel.good => AppColors.green,
      };

  IconData _icon(InsightLevel l) => switch (l) {
        InsightLevel.critical => Icons.error_outline,
        InsightLevel.warn => Icons.warning_amber_rounded,
        InsightLevel.watch => Icons.visibility_outlined,
        InsightLevel.info => Icons.info_outline,
        InsightLevel.good => Icons.check_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    final insights = InsightsEngine.generate(
      batches: batches,
      eggs: eggs,
      feed: feed,
      mortality: mortality,
      vacc: vacc,
    );
    if (insights.isEmpty) return const SizedBox.shrink();
    final forecast = InsightsEngine.forecastEggs7(eggs);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                'Farm Intelligence',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (forecast > 0)
                Text(
                  '~$forecast eggs next 7 days',
                  style: GoogleFonts.inter(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((i) {
            final c = _color(i.level);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon(i.level), size: 16, color: c),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.title,
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 1),
                        Text(i.message,
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Farm Performance Score — FarmNest's single farm-health indicator,
/// an equal blend of egg quality, flock survival, and vaccination
/// compliance. A quick "how is my farm doing?" read.
class _PerformanceScoreCard extends StatelessWidget {
  const _PerformanceScoreCard({
    required this.batches,
    required this.eggs,
    required this.vacc,
  });

  final BatchProvider batches;
  final EggProductionProvider eggs;
  final VaccinationProvider vacc;

  @override
  Widget build(BuildContext context) {
    final totalEggs = eggs.records.fold(0, (s, e) => s + e.eggCount);
    final goodEggs = eggs.records.fold(0, (s, e) => s + e.goodCount);
    final quality = totalEggs > 0 ? goodEggs / totalEggs : 1.0;

    final initial = batches.totalInitialBirds;
    final survival = initial > 0 ? batches.totalBirds / initial : 1.0;

    final done = vacc.vaccinations
        .where((v) => v.status == VaccinationStatus.completed)
        .length;
    final overdue = vacc.overdueCount;
    final dueToDate = done + overdue;
    final compliance = dueToDate > 0 ? done / dueToDate : 1.0;

    // No data at all → don't show a misleading 100%.
    final hasData = totalEggs > 0 || initial > 0 || dueToDate > 0;
    final score =
        (((quality + survival + compliance) / 3) * 100).round();
    final label = score >= 90
        ? 'Excellent'
        : score >= 75
            ? 'Good'
            : score >= 60
                ? 'Fair'
                : 'Needs attention';
    final color = score >= 75
        ? AppColors.green
        : score >= 60
            ? AppColors.amber
            : AppColors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(
                    value: hasData ? score / 100 : 0,
                    strokeWidth: 6,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  hasData ? '$score' : '—',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm Performance Score',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasData
                      ? '$label · egg quality, flock survival & vaccine compliance'
                      : 'Start recording eggs, batches and vaccines to see your score',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // A single Border can't mix borderRadius with non-uniform side colors
    // (Flutter throws "A borderRadius can only be given on borders with
    // uniform colors" at paint time), so the colored top accent is layered
    // on top of a plain rounded/uniform-border container instead.
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 13, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        hoverColor: AppColors.amber.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
