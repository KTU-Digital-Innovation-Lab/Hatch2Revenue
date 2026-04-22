import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/farm_profile_provider.dart';
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
    if (hour < 12) return 'Good morning 🐓';
    if (hour < 17) return 'Good afternoon 🐓';
    return 'Good evening 🐓';
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
                  style: GoogleFonts.syne(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome to $farmName. Select a module below to manage your flock.',
                  style: GoogleFonts.dmMono(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

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
                  emoji: '🐣',
                  title: 'Batch Lifecycle',
                  sub: '${batchProvider.batches.length} active batch${batchProvider.batches.length != 1 ? "es" : ""}',
                  onTap: () => MainNavigation.navigateTo(context, 1),
                ),
                _NavCard(
                  emoji: '💉',
                  title: 'Vaccination',
                  sub: '${vaccProvider.scheduledCount} scheduled',
                  onTap: () => MainNavigation.navigateTo(context, 2),
                ),
                _NavCard(
                  emoji: '🌾',
                  title: 'Feed Monitor',
                  sub: feedKg > 0 ? '${feedKg.toStringAsFixed(0)}kg consumed' : 'No feed data',
                  onTap: () => MainNavigation.navigateTo(context, 3),
                ),
                _NavCard(
                  emoji: '🥚',
                  title: 'Egg Production',
                  sub: '${eggProvider.totalEggs} total eggs',
                  onTap: () => MainNavigation.navigateTo(context, 4),
                ),
                _NavCard(
                  emoji: '⚠️',
                  title: 'Mortality Log',
                  sub: '${mortalityProvider.records.length} records',
                  onTap: () => MainNavigation.navigateTo(context, 5),
                ),
                _NavCard(
                  emoji: '💰',
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

class _NavCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _NavCard({
    required this.emoji,
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
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmMono(
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
