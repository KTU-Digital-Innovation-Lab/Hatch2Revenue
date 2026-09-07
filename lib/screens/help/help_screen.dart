import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

/// In-app guide. Each entry describes how the app ACTUALLY behaves, so
/// it stays a true reference rather than marketing copy.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<({IconData icon, String title, String body})> _topics = [
    (
      icon: Icons.play_circle_outline,
      title: 'Getting started',
      body: 'Add a batch (a flock) from the Batches tab. Give it a name, breed, '
          'the source of the chicks, the entry date and how many birds you '
          'received. If you have created houses, you can also pick which house '
          'the flock lives in. Once a batch exists, everything else — eggs, '
          'feed, deaths, vaccines — is recorded against it.',
    ),
    (
      icon: Icons.timeline,
      title: 'Batches & lifecycle',
      body: 'A flock moves through Brooding, then Grower, then Layer '
          'automatically, based on its age in weeks (it becomes a layer from '
          'about 16 weeks). You do not change the stage by hand. Tap a batch to '
          'open its hub, where you can log eggs, feed, deaths, vaccines and '
          'monitoring for that exact flock, and see its running totals.',
    ),
    (
      icon: Icons.edit_note,
      title: 'Daily logging',
      body: 'Use Quick Daily Log on the home screen to record eggs, feed and '
          'deaths for the day in one place, or open a batch and log from its '
          'hub. Eggs are counted in crates, where 30 eggs make one crate.',
    ),
    (
      icon: Icons.grass,
      title: 'Feed & forecast',
      body: 'Add feed stock in bags (1 bag = 50 kg) and log daily consumption. '
          'The Feed screen shows a Feed Forecast — about how many bags your '
          'flock will need over the next 7 and 30 days, based on its size and '
          'age. When any stock runs low or expires, the app shows an alert and '
          'sends a phone notification so you can reorder in time.',
    ),
    (
      icon: Icons.monitor_weight_outlined,
      title: 'Flock monitoring',
      body: 'From a batch hub, tap Log monitoring to record weight, temperature '
          'and water. Each has its own trend chart — the weight chart is a '
          'growth curve — so you can see how the flock is developing and spot '
          'problems early.',
    ),
    (
      icon: Icons.vaccines_outlined,
      title: 'Vaccinations & reminders',
      body: 'Schedule a vaccine and the app reminds you the day before and '
          'again on the morning it is due, as a phone notification. Mark each '
          'one done when given. The Vaccination screen shows overdue, upcoming '
          'and completed counts and your compliance rate.',
    ),
    (
      icon: Icons.monitor_heart_outlined,
      title: 'Mortality & health',
      body: 'Record deaths with a cause. The app charts deaths week by week and '
          'warns you of a possible disease threat if losses rise sharply or one '
          'cause starts to dominate — a prompt to inspect the flock or call a '
          'vet, never a diagnosis.',
    ),
    (
      icon: Icons.point_of_sale,
      title: 'Egg sales & debtors',
      body: 'Record a sale with the buyer, crates and how much they paid. The '
          'app tracks who has paid in full and who still owes you, so a credit '
          'sale is never forgotten.',
    ),
    (
      icon: Icons.payments_outlined,
      title: 'Money & costs',
      body: 'Financials shows total revenue, expenses and net profit (shown as '
          'a negative figure when you are spending more than you earn), plus '
          'cost per bird and cost per egg. Feed purchases and bird purchases '
          'are posted to your expenses automatically.',
    ),
    (
      icon: Icons.speed,
      title: 'Productivity',
      body: 'The Productivity dashboard (in More) brings the efficiency numbers '
          'together: hen-day laying rate, survival, feed conversion (FCR), eggs '
          'per bird and unit costs, with a short plain-language reading of how '
          'the flock is doing.',
    ),
    (
      icon: Icons.groups_outlined,
      title: 'Team & roles',
      body: 'Invite workers with your farm invite code. The owner and managers '
          'see everything. Workers log daily records and can record sales, but '
          'never see money totals, and cannot edit or delete records — so a '
          'collection cannot be quietly changed. A vet handles health only. '
          'Roles are set from the Team screen.',
    ),
    (
      icon: Icons.cloud_off,
      title: 'Offline & syncing',
      body: 'The app works fully offline — your records are saved on the phone '
          'first, so nothing is lost without a signal. When you have internet '
          'and are signed in, your data syncs to the cloud and to any other '
          'device on the same farm.',
    ),
    (
      icon: Icons.notifications_active_outlined,
      title: 'Notifications',
      body: 'Allow notifications when the app asks. You will then receive '
          'vaccination reminders and low-feed alerts. You can change the '
          'day-before reminder time under Settings, Start-up & reminders.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Help & Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'A quick guide to how Hatch2Revenue works. Tap a topic to expand it.',
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (final t in _topics)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(t.icon, color: AppColors.amber),
                  title: Text(
                    t.title,
                    style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  iconColor: AppColors.textSecondary,
                  collapsedIconColor: AppColors.textSecondary,
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t.body,
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
