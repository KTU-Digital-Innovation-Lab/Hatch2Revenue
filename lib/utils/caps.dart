import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';

/// What the current user is allowed to do, from their farm role.
///
/// Mirrors the server-side rules in `supabase/h2r_roles_schema.sql` so
/// the app only shows actions that will actually succeed. The server is
/// the real guard; this is the UX layer over it.
///
/// A solo user (no farm) or a member not yet approved is treated as the
/// owner of their own data — they have full access to it, exactly as
/// before teams existed.
class Caps {
  /// null = solo user / no farm → full access to own data.
  final String? role;
  const Caps(this.role);

  factory Caps.of(BuildContext context, {bool listen = true}) {
    final sync =
        listen ? context.watch<SyncService>() : context.read<SyncService>();
    final m = sync.membership;
    if (m == null || !m.isApproved) return const Caps(null);
    return Caps(m.role);
  }

  bool get _full => role == null || role == 'owner';

  bool get isOwner => _full;
  bool get isManager => role == 'manager';
  bool get isWorker => role == 'worker';
  bool get isVet => role == 'vet';

  /// Only the owner runs the team and sets prices.
  bool get canManageTeam => _full;
  bool get canSetPrices => _full;

  /// Owner + manager: edit or delete records, see finances, set up
  /// flocks, and manage stock.
  bool get canAmend => _full || role == 'manager';

  /// Seeing money — totals, profit, the debtors ledger — is owner/manager
  /// only. Workers record sales but never see the books.
  bool get canSeeMoney => canAmend;

  /// Daily logging (eggs, feed): everyone except the vet.
  bool get canLogEggs => canAmend || role == 'worker';
  bool get canLogFeed => canAmend || role == 'worker';

  /// Recording a sale is a daily-log action: owner, manager and worker
  /// can sell. What differs is that only owner/manager see the ledger
  /// and totals ([canSeeMoney]).
  bool get canSell => canLogEggs;

  /// The vet has no reason to see egg production or sales.
  bool get canSeeEggs => canLogEggs;

  /// Anyone approved can record a death; the vet and owner/manager can
  /// also annotate the cause afterwards.
  bool get canRecordDeaths => _full || role == 'manager' || role == 'worker' || role == 'vet';
  bool get canEditDeaths => canAmend || role == 'vet';

  /// Health: owner, manager, and vet manage the vaccination schedule.
  bool get canManageVaccines => canAmend || role == 'vet';

  /// A short human label for the role, for the team screen.
  String get label {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'manager':
        return 'Manager';
      case 'vet':
        return 'Veterinary';
      case 'worker':
        return 'Worker';
      default:
        return 'You';
    }
  }
}
