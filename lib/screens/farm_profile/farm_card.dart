import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';
import '../feed/feed_prices_screen.dart';
import 'team_screen.dart';

/// "My Farm" card — create or join a farm, see approval status, and
/// (for owners) manage the team and official feed prices.
class FarmCard extends StatefulWidget {
  const FarmCard({super.key});

  @override
  State<FarmCard> createState() => _FarmCardState();
}

class _FarmCardState extends State<FarmCard>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.red : AppColors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _run(Future<void> Function() op) async {
    setState(() => _busy = true);
    try {
      await op();
    } catch (e) {
      _toast(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptCreate() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create your farm'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Farm name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _run(() async {
      await context.read<SyncService>().createFarm(name);
      _toast('Farm "$name" created. You are the owner.');
    });
  }

  Future<void> _promptJoin() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a farm'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration:
              const InputDecoration(labelText: 'Invite code from the owner'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Request to Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    await _run(() async {
      final status = await context.read<SyncService>().joinFarm(code);
      _toast(status == 'approved'
          ? 'You are in!'
          : 'Request sent — the farm owner must approve you before '
              'any farm records become visible.');
    });
  }

  Widget _codeAction({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Future<void> _promptRotate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New invite code?'),
        content: Text(
          'The current code stops working immediately — anyone you have '
          'already approved keeps their access. Share the new code with '
          'future workers.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate New Code'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final code = await context.read<SyncService>().rotateInviteCode();
      _toast('New invite code: $code');
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final m = sync.membership;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // A gently bobbing hen keeps the flock feeling alive.
              AnimatedBuilder(
                animation: _bob,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, -2 * _bob.value),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset('assets/chicken.png',
                      height: 26, width: 26, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'My Farm',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (m != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (m.isApproved ? AppColors.green : AppColors.amber)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    m.isApproved
                        ? (m.isOwner ? 'Owner' : m.role)
                        : 'Awaiting approval',
                    style: TextStyle(
                      color: m.isApproved ? AppColors.green : AppColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!sync.isSignedIn)
            Text(
              'Sign in above first — then create your farm or join one '
              'with an invite code.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          else if (m == null) ...[
            Text(
              'Run your farm as a team: the owner creates the farm, '
              'workers join with an invite code, and every record syncs '
              'to everyone once the owner approves them.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _promptCreate,
                    icon: const Icon(Icons.agriculture, size: 18),
                    label: const Text('Create Farm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _promptJoin,
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('Join Farm'),
                  ),
                ),
              ],
            ),
          ] else if (!m.isApproved) ...[
            Text(
              'You asked to join "${m.farmName}". The owner has to approve '
              'you before farm records become visible — check back soon.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await context.read<SyncService>().refreshMembership();
                        final now = context.read<SyncService>().membership;
                        _toast(now?.isApproved == true
                            ? 'Approved — welcome to ${now!.farmName}!'
                            : 'Still waiting for the owner.');
                      }),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check Approval'),
            ),
          ] else ...[
            Text(
              m.farmName,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (m.isOwner && m.inviteCode != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text('Invite code',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m.inviteCode!,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _codeAction(
                      icon: Icons.copy_outlined,
                      tooltip: 'Copy code',
                      onTap: () async {
                        await Clipboard.setData(
                            ClipboardData(text: m.inviteCode!));
                        _toast('Invite code copied');
                      },
                    ),
                    _codeAction(
                      icon: Icons.share_outlined,
                      tooltip: 'Share invite',
                      onTap: () => SharePlus.instance.share(ShareParams(
                        subject: 'Join ${m.farmName} on Hatch2Revenue',
                        text: 'Join my farm "${m.farmName}" on Hatch2Revenue!\n\n'
                            '1. Install the Hatch2Revenue app\n'
                            '2. Create your account (Farm Profile → Sign up)\n'
                            '3. Open Farm Profile → My Farm → Join Farm\n'
                            '4. Enter this invite code: ${m.inviteCode}\n\n'
                            'I will approve you from my side — then everything '
                            'you record syncs to the farm.',
                      )),
                    ),
                    _codeAction(
                      icon: Icons.autorenew,
                      tooltip: 'New code',
                      onTap: _busy ? null : _promptRotate,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (m.isOwner) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TeamScreen()),
                      ),
                      icon: const Icon(Icons.group_outlined, size: 18),
                      label: const Text('Team'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const FeedPricesScreen()),
                    ),
                    icon: const Icon(Icons.price_change_outlined, size: 18),
                    label: const Text('Feed Prices'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
