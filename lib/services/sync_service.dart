import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed_catalog_item.dart';
import 'database_service.dart';
import 'supabase_config.dart';

/// The caller's farm membership as the server sees it.
class FarmMembership {
  final String farmId;
  final String farmName;
  final String role; // owner | manager | worker | ...
  final String status; // pending | approved
  final String? inviteCode; // only visible to the owner

  const FarmMembership({
    required this.farmId,
    required this.farmName,
    required this.role,
    required this.status,
    this.inviteCode,
  });

  bool get isOwner => role == 'owner';
  bool get isApproved => status == 'approved';
}

class FarmMember {
  final String farmId;
  final String userId;
  final String email;
  final String role;
  final String status;

  const FarmMember({
    required this.farmId,
    required this.userId,
    required this.email,
    required this.role,
    required this.status,
  });
}

/// Offline-first cloud sync.
///
/// The local SQLite database is always the source of truth for the UI.
/// Every local change lands in the `sync_outbox` queue; when internet
/// is available (and the farmer is signed in) the queue is pushed to
/// Supabase, then remote changes are pulled down using a per-table
/// `server_updated_at` cursor. Conflicts resolve last-write-wins by
/// the row's `updatedAt` timestamp.
class SyncService extends ChangeNotifier {
  SyncService();

  final _db = DatabaseService.instance;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _syncing = false;
  int _pendingCount = 0;
  String? _lastSyncAt;
  String? _lastError;
  FarmMembership? _membership;
  List<FeedCatalogItem> _catalog = const [];

  bool get syncing => _syncing;
  int get pendingCount => _pendingCount;
  String? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;

  /// Current farm membership (null when the user has no farm yet).
  FarmMembership? get membership => _membership;

  /// Owner-set feed prices, cached locally so they work offline.
  List<FeedCatalogItem> get catalog => _catalog;

  bool get isSignedIn =>
      _supabaseReady && Supabase.instance.client.auth.currentUser != null;
  String? get userEmail => _supabaseReady
      ? Supabase.instance.client.auth.currentUser?.email
      : null;

  /// Called after a pull applies remote rows, so the app can reload
  /// its providers from the database.
  Future<void> Function()? onDataChanged;

  static bool _supabaseReady = false;

  /// Safe to call offline — Supabase.initialize does not require a
  /// connection (the session is restored from local storage).
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _supabaseReady = true;
    } catch (e) {
      debugPrint('SyncService: Supabase init failed ($e) — sync disabled.');
    }
  }

  /// Starts connectivity watching and loads persisted sync state.
  Future<void> start() async {
    if (!_supabaseReady) return;
    _lastSyncAt = await _db.getMeta('last_sync_at');
    await _loadMembershipFromMeta();
    await _loadCatalogFromDb();
    await refreshPendingCount();
    if (isSignedIn) {
      // Best-effort: pick up approval/price changes on launch.
      refreshMembership().catchError((_) {});
    }

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && isSignedIn && _pendingCount > 0 && !_syncing) {
        // Internet is back — push what the farmer recorded offline.
        syncNow();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> refreshPendingCount() async {
    if (!_supabaseReady) return;
    try {
      _pendingCount = await _db.getOutboxCount();
      notifyListeners();
    } catch (e) {
      debugPrint('SyncService: pending count failed: $e');
    }
  }

  // ---------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------

  Future<void> signIn(String email, String password) async {
    _requireSupabase();
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await _backfillIfFirstSignIn();
    notifyListeners();
  }

  /// Returns true when the account needs email confirmation first.
  Future<bool> signUp(
    String email,
    String password, {
    String? fullName,
    String? phone,
  }) async {
    _requireSupabase();
    final res = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    if (res.session == null) return true; // confirm-email flow
    await _backfillIfFirstSignIn();
    notifyListeners();
    return false;
  }

  /// Confirms a new account with the 8-digit code from the
  /// Hatch2Revenue email, signing the user in.
  Future<void> verifySignupCode(String email, String code) async {
    _requireSupabase();
    await Supabase.instance.client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: code,
    );
    await _backfillIfFirstSignIn();
    notifyListeners();
  }

  Future<void> resendSignupCode(String email) async {
    _requireSupabase();
    await Supabase.instance.client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  /// Emails a 8-digit recovery code.
  Future<void> requestPasswordReset(String email) async {
    _requireSupabase();
    await Supabase.instance.client.auth.resetPasswordForEmail(email);
  }

  /// Verifies the recovery code and sets the new password. The user
  /// ends up signed in.
  Future<void> resetPasswordWithCode(
    String email,
    String code,
    String newPassword,
  ) async {
    _requireSupabase();
    final client = Supabase.instance.client;
    await client.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: code,
    );
    await client.auth.updateUser(UserAttributes(password: newPassword));
    await _backfillIfFirstSignIn();
    notifyListeners();
  }

  Future<void> signOut() async {
    _requireSupabase();
    await Supabase.instance.client.auth.signOut();
    notifyListeners();
  }

  /// The first time this device signs in, queue the farmer's entire
  /// existing history so it reaches the cloud.
  Future<void> _backfillIfFirstSignIn() async {
    final done = await _db.getMeta('backfill_done');
    if (done == '1') return;
    await _db.enqueueAllExisting();
    await _db.setMeta('backfill_done', '1');
    await refreshPendingCount();
  }

  void _requireSupabase() {
    if (!_supabaseReady) {
      throw Exception('Cloud sync is unavailable on this device.');
    }
  }

  // ---------------------------------------------------------------
  // Farms, membership & the owner-priced feed catalog
  // ---------------------------------------------------------------

  Future<void> _loadMembershipFromMeta() async {
    final farmId = await _db.getMeta('farm_id');
    if (farmId == null) {
      _membership = null;
      return;
    }
    _membership = FarmMembership(
      farmId: farmId,
      farmName: await _db.getMeta('farm_name') ?? 'My Farm',
      role: await _db.getMeta('farm_role') ?? 'worker',
      status: await _db.getMeta('farm_status') ?? 'pending',
      inviteCode: await _db.getMeta('farm_invite_code'),
    );
  }

  Future<void> _storeMembership(FarmMembership? m) async {
    _membership = m;
    await _db.setMeta('farm_id', m?.farmId ?? '');
    if (m == null) {
      await _db.setMeta('farm_name', '');
      await _db.setMeta('farm_role', '');
      await _db.setMeta('farm_status', '');
      await _db.setMeta('farm_invite_code', '');
    } else {
      await _db.setMeta('farm_name', m.farmName);
      await _db.setMeta('farm_role', m.role);
      await _db.setMeta('farm_status', m.status);
      await _db.setMeta('farm_invite_code', m.inviteCode ?? '');
    }
    notifyListeners();
  }

  Future<void> _loadCatalogFromDb() async {
    try {
      final rows = await _db.getCatalog();
      _catalog = rows.map(FeedCatalogItem.fromMap).toList();
    } catch (e) {
      debugPrint('SyncService: catalog load failed: $e');
    }
  }

  /// Asks the server for the caller's membership and (when approved)
  /// refreshes the locally cached feed catalog.
  Future<void> refreshMembership() async {
    _requireSupabase();
    if (!isSignedIn) return;
    final data =
        await Supabase.instance.client.rpc('h2r_my_membership');
    if (data == null) {
      await _storeMembership(null);
      return;
    }
    final wasApproved = _membership?.isApproved ?? false;
    final m = FarmMembership(
      farmId: data['farm_id'] as String,
      farmName: data['farm_name'] as String,
      role: data['role'] as String,
      status: data['status'] as String,
      inviteCode: data['invite_code'] as String?,
    );
    await _storeMembership(m);
    if (m.isApproved) {
      await refreshCatalog();
      if (!wasApproved) {
        // Just approved: send the farmer's history up to the farm.
        await _db.enqueueAllExisting();
        await refreshPendingCount();
      }
    }
  }

  Future<void> createFarm(String name) async {
    _requireSupabase();
    if (!isSignedIn) throw Exception('Sign in first.');
    await Supabase.instance.client.from('h2r_farms').insert({
      'name': name,
      'owner_id': Supabase.instance.client.auth.currentUser!.id,
    });
    await refreshMembership();
  }

  /// Returns the resulting status ('pending' until the owner approves).
  Future<String> joinFarm(String code) async {
    _requireSupabase();
    if (!isSignedIn) throw Exception('Sign in first.');
    final data = await Supabase.instance.client
        .rpc('h2r_join_farm', params: {'code': code.trim()});
    await refreshMembership();
    return data['status'] as String;
  }

  /// Owner-only: invalidates the current invite code and returns a
  /// fresh dictation-friendly one. Approved members keep their access.
  /// Requires supabase/h2r_invite_codes.sql applied on the server.
  Future<String> rotateInviteCode() async {
    _requireSupabase();
    if (!isSignedIn) throw Exception('Sign in first.');
    try {
      final code = await Supabase.instance.client
          .rpc('h2r_rotate_invite_code') as String;
      await refreshMembership();
      return code;
    } on PostgrestException catch (e) {
      if (e.message.contains('h2r_rotate_invite_code')) {
        throw Exception(
            'Server update needed: run supabase/h2r_invite_codes.sql '
            'in the Supabase SQL editor, then try again.');
      }
      rethrow;
    }
  }

  Future<List<FarmMember>> listMembers() async {
    _requireSupabase();
    final m = _membership;
    if (m == null) return const [];
    final rows = await Supabase.instance.client
        .from('h2r_farm_members')
        .select()
        .eq('farm_id', m.farmId)
        .order('requested_at');
    return rows
        .map<FarmMember>((r) => FarmMember(
              farmId: r['farm_id'] as String,
              userId: r['user_id'] as String,
              email: r['email'] as String? ?? '',
              role: r['role'] as String? ?? 'worker',
              status: r['status'] as String? ?? 'pending',
            ))
        .toList();
  }

  Future<void> setMemberStatus(String userId, String status) async {
    _requireSupabase();
    final m = _membership;
    if (m == null || !m.isOwner) throw Exception('Only the owner can do this.');
    await Supabase.instance.client
        .from('h2r_farm_members')
        .update({
          'status': status,
          if (status == 'approved')
            'approved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('farm_id', m.farmId)
        .eq('user_id', userId);
  }

  Future<void> refreshCatalog() async {
    final m = _membership;
    if (m == null || !m.isApproved) return;
    final rows = await Supabase.instance.client
        .from('h2r_feed_catalog')
        .select()
        .eq('farm_id', m.farmId)
        .order('feed_name');
    final items = rows.map<FeedCatalogItem>(FeedCatalogItem.fromMap).toList();
    await _db.replaceCatalog(items.map((i) => i.toLocalMap()).toList());
    _catalog = items;
    notifyListeners();
  }

  /// Strictly the owner — RLS rejects anyone else server-side too.
  Future<void> updateFeedPrice(String catalogId, double newPrice) async {
    _requireSupabase();
    final m = _membership;
    if (m == null || !m.isOwner) {
      throw Exception('Only the farm owner can change feed prices.');
    }
    await Supabase.instance.client
        .from('h2r_feed_catalog')
        .update({'price_per_bag': newPrice})
        .eq('id', catalogId);
    await refreshCatalog();
  }

  // ---------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------

  Future<String> syncNow() async {
    _requireSupabase();
    if (!isSignedIn) throw Exception('Sign in to sync.');
    if (_syncing) return 'Sync already running.';

    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      // Approval status or prices may have changed since last sync.
      await refreshMembership();

      final pushed = await _push();
      final pulled = await _pull();

      _lastSyncAt = DateTime.now().toIso8601String();
      await _db.setMeta('last_sync_at', _lastSyncAt!);
      await refreshPendingCount();

      if (pulled > 0) await onDataChanged?.call();
      return 'Synced: $pushed uploaded, $pulled downloaded.';
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Uploads every queued row (its CURRENT state, including the
  /// tombstone marker for deletes). Outbox entries are only cleared
  /// after the server accepts the rows.
  Future<int> _push() async {
    final client = Supabase.instance.client;
    final outbox = await _db.getOutbox();
    if (outbox.isEmpty) return 0;

    var pushed = 0;
    final byTable = <String, List<String>>{};
    for (final entry in outbox) {
      byTable
          .putIfAbsent(entry['tableName'] as String, () => [])
          .add(entry['rowId'] as String);
    }

    // Rows belong to the farm once the member is approved; otherwise
    // they stay private to this account.
    final farmId =
        (_membership?.isApproved ?? false) ? _membership!.farmId : null;

    for (final entry in byTable.entries) {
      final table = entry.key;
      final rows = <Map<String, dynamic>>[];
      for (final id in entry.value) {
        final row = await _db.getRowById(table, id);
        // A null row was hard-deleted locally — nothing to send.
        if (row != null) rows.add({...row, 'farm_id': farmId});
      }
      if (rows.isNotEmpty) {
        // Throws on failure, which aborts before the queue is cleared —
        // the rows simply retry on the next sync.
        await client.from('h2r_$table').upsert(rows);
        pushed += rows.length;
      }
      for (final id in entry.value) {
        await _db.clearOutboxEntry(table, id);
      }
    }
    return pushed;
  }

  /// Downloads rows changed on the server since the last pull and
  /// applies the newer version locally (last-write-wins on updatedAt).
  Future<int> _pull() async {
    final client = Supabase.instance.client;
    var applied = 0;

    for (final table in DatabaseService.syncedTables) {
      final cursorKey = 'pull_cursor_$table';
      final cursor =
          await _db.getMeta(cursorKey) ?? '1970-01-01T00:00:00+00:00';

      final remote = await client
          .from('h2r_$table')
          .select()
          .gt('server_updated_at', cursor)
          .order('server_updated_at', ascending: true)
          .limit(1000);

      String? newCursor;
      for (final raw in remote) {
        final row = Map<String, dynamic>.from(raw)
          ..remove('user_id')
          ..remove('farm_id')
          ..remove('server_updated_at');
        newCursor = raw['server_updated_at'] as String;

        final local = await _db.getRowById(table, row['id'] as String);
        final remoteUpdated = (row['updatedAt'] as String?) ?? '';
        final localUpdated = (local?['updatedAt'] as String?) ?? '';
        if (local == null || remoteUpdated.compareTo(localUpdated) > 0) {
          await _db.applyRemote(table, row);
          applied++;
        }
      }
      if (newCursor != null) {
        await _db.setMeta(cursorKey, newCursor);
      }
    }
    return applied;
  }
}
