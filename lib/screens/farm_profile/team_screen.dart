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

  Future<void> _setRole(FarmMember member, String role,
      {bool approve = false}) async {
    try {
      await context
          .read<SyncService>()
          .setMemberRole(member.userId, role, approve: approve);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve
            ? '${member.email} approved as ${_roleName(role)}.'
            : '${member.email} is now a ${_roleName(role)}.'),
        backgroundColor: AppColors.green,
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

  static const _roles = ['worker', 'vet', 'manager'];

  static String _roleName(String r) {
    switch (r) {
      case 'owner':
        return 'Owner';
      case 'manager':
        return 'Manager';
      case 'vet':
        return 'Veterinary';
      default:
        return 'Worker';
    }
  }

  static String _roleBlurb(String r) {
    switch (r) {
      case 'manager':
        return 'Deputy: edit and delete records, see finances. Not team or prices.';
      case 'vet':
        return 'Health only: vaccinations, record deaths, read flocks and feed. No money.';
      default:
        return 'Logs eggs, feed and deaths. Cannot edit, delete, or see money.';
    }
  }

  /// Bottom sheet to choose a role, used both when approving a pending
  /// request and when changing an existing member's role.
  Future<void> _pickRole(FarmMember member, {required bool approve}) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approve ? 'Approve ${member.email} as' : 'Change role',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final r in _roles)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(ctx, r),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: member.role == r
                              ? AppColors.green
                              : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_roleName(r),
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(_roleBlurb(r),
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      await _setRole(member, chosen, approve: approve);
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
                          tooltip: 'Approve & set role',
                          icon:
                              Icon(Icons.check_circle, color: AppColors.green),
                          onPressed: () => _pickRole(m, approve: true),
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
              ...approved.map((m) {
                final isOwner = m.role == 'owner';
                final chip = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: isOwner
                        ? null
                        : Border.all(
                            color: AppColors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_roleName(m.role),
                          style: TextStyle(
                              color: AppColors.green, fontSize: 11)),
                      if (!isOwner) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.edit, size: 12, color: AppColors.green),
                      ],
                    ],
                  ),
                );
                return _memberTile(
                  m,
                  // The owner can retune anyone's role except their own.
                  trailing: isOwner
                      ? chip
                      : InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _pickRole(m, approve: false),
                          child: chip,
                        ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Tap a role to change it. Workers can log records but not '
                'edit, delete, or see money. Managers are deputies; vets '
                'handle health only.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
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
