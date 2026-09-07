import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Collects in-app ratings and reviews and delivers them to the
/// `h2r_feedback` table in Supabase, where the developer reads them from
/// the dashboard.
///
/// Offline-first, like the rest of the app: a submission is uploaded
/// immediately when there is a connection, otherwise it is queued on the
/// device and sent on the next one. Feedback is therefore never lost, and
/// it works for farmers who have no cloud account (uploaded anonymously).
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  static const _table = 'h2r_feedback';
  static const _queueKey = 'pending_feedback';

  String versionName = '';
  String buildNumber = '';
  bool _flushing = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Full version string attached to feedback, e.g. "1.7.1+21".
  String get appVersion =>
      versionName.isEmpty ? '' : '$versionName+$buildNumber';

  /// Reads the running version and sends anything queued from a previous
  /// offline session. Call once at start-up, after Supabase is
  /// initialised. Never throws — feedback must not break launch.
  Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      versionName = info.version;
      buildNumber = info.buildNumber;
    } catch (e) {
      debugPrint('Feedback: version read failed: $e');
    }
    await flushPending();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) flushPending();
    });
  }

  /// Records a [rating] (1–5) with an optional [review]. Returns true if
  /// it reached the server now, false if it was queued for later. Either
  /// way the farmer's feedback is kept.
  Future<bool> submit({required int rating, String? review}) async {
    final text = review?.trim();
    final payload = <String, dynamic>{
      'rating': rating,
      'review': (text == null || text.isEmpty) ? null : text,
      'app_version': appVersion.isEmpty ? null : appVersion,
      'platform': _platform(),
      'user_email': _currentEmail(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await Supabase.instance.client.from(_table).insert(payload);
      await flushPending(); // opportunistically drain any backlog too
      return true;
    } catch (e) {
      debugPrint('Feedback upload deferred (offline?): $e');
      await _enqueue(payload);
      return false;
    }
  }

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_queueKey) ?? <String>[];
    list.add(jsonEncode(payload));
    await prefs.setStringList(_queueKey, list);
  }

  /// Tries to upload every queued submission. Items that still fail
  /// (offline) are kept for next time; the guard stops two flushes from
  /// racing and double-sending.
  Future<void> flushPending() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_queueKey) ?? <String>[];
      if (list.isEmpty) return;
      final remaining = <String>[];
      for (final raw in list) {
        try {
          final payload = jsonDecode(raw) as Map<String, dynamic>;
          await Supabase.instance.client.from(_table).insert(payload);
        } catch (_) {
          remaining.add(raw); // still unreachable — keep it
        }
      }
      await prefs.setStringList(_queueKey, remaining);
    } finally {
      _flushing = false;
    }
  }

  String _platform() {
    try {
      return Platform.operatingSystem; // android / ios / windows
    } catch (_) {
      return 'unknown';
    }
  }

  String? _currentEmail() {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _sub?.cancel();
}
