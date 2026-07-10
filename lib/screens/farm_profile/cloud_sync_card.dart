import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';
import '../auth/auth_screen.dart';

/// Sync status card. The app works fully offline; this is where the
/// farmer connects an account so records copy to the cloud whenever
/// internet is available.
class CloudSyncCard extends StatefulWidget {
  const CloudSyncCard({super.key});

  @override
  State<CloudSyncCard> createState() => _CloudSyncCardState();
}

class _CloudSyncCardState extends State<CloudSyncCard> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Show an up-to-date queued-changes badge when the card appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SyncService>().refreshPendingCount();
    });
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.red : AppColors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _openAuth(AuthMode mode) async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AuthScreen(initialMode: mode)),
    );
    if (signedIn == true && mounted) {
      _toast('Signed in. Your records will now sync.');
      await context.read<SyncService>().refreshPendingCount();
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      final summary = await context.read<SyncService>().syncNow();
      _toast(summary);
    } catch (e) {
      _toast(_friendly(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'No internet connection — your changes stay queued and '
          'will sync when you are online.';
    }
    return s.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();

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
              Icon(Icons.cloud_sync_outlined,
                  size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                'Cloud Sync',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sync.isSignedIn
                ? 'Signed in as ${sync.userEmail}. Changes sync '
                    'automatically whenever this device is online.'
                : 'The app works fully offline. Sign in to keep a safe '
                    'copy of your records online — they upload whenever '
                    'you have internet.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (!sync.isSignedIn)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openAuth(AuthMode.signIn),
                    child: const Text('Sign In'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openAuth(AuthMode.signUp),
                    child: const Text('Create Account'),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                _StatusChip(
                  icon: Icons.pending_actions,
                  label: sync.pendingCount == 0
                      ? 'All changes synced'
                      : '${sync.pendingCount} waiting to upload',
                  color: sync.pendingCount == 0
                      ? AppColors.green
                      : AppColors.amber,
                ),
                const SizedBox(width: 8),
                if (sync.lastSyncAt != null)
                  _StatusChip(
                    icon: Icons.history,
                    label: 'Last sync ${_fmt(sync.lastSyncAt!)}',
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy || sync.syncing ? null : _syncNow,
                    icon: sync.syncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(sync.syncing ? 'Syncing…' : 'Sync Now'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await context.read<SyncService>().signOut();
                          _toast(
                            'Signed out. The app keeps working offline.',
                          );
                        },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('d MMM, HH:mm').format(dt);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
