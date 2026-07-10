import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';

/// Owner's team management: approve or reject join requests. Nobody
/// sees farm data until they are approved here (enforced server-side).
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<FarmMember>? _members;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await context.read<SyncService>().listMembers();
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _setStatus(FarmMember member, String status) async {
    try {
      await context.read<SyncService>().setMemberStatus(member.userId, status);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'approved'
            ? '${member.email} approved — they can now see farm records.'
            : '${member.email} rejected.'),
        backgroundColor:
            status == 'approved' ? AppColors.green : AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        (_members ?? []).where((m) => m.status == 'pending').toList();
    final approved =
        (_members ?? []).where((m) => m.status == 'approved').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Team')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(_error!, style: TextStyle(color: AppColors.red)),
            if (_members == null && _error == null)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )),
            if (pending.isNotEmpty) ...[
              _sectionTitle('Waiting for your approval', AppColors.amber),
              ...pending.map((m) => _memberTile(
                    m,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Approve',
                          icon:
                              Icon(Icons.check_circle, color: AppColors.green),
                          onPressed: () => _setStatus(m, 'approved'),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          icon: Icon(Icons.cancel, color: AppColors.red),
                          onPressed: () => _setStatus(m, 'rejected'),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (_members != null) ...[
              _sectionTitle('Team members', AppColors.green),
              if (approved.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Just you so far. Share your invite code so workers '
                    'can request to join.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ...approved.map((m) => _memberTile(
                    m,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        m.role,
                        style:
                            TextStyle(color: AppColors.green, fontSize: 11),
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _memberTile(FarmMember m, {required Widget trailing}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.amber.withValues(alpha: 0.15),
              child: Text(
                (m.email.isNotEmpty ? m.email[0] : '?').toUpperCase(),
                style: TextStyle(color: AppColors.amber, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.email,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
            trailing,
          ],
        ),
      );
}
