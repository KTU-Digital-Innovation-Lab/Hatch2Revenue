import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/feedback_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts are bundled under google_fonts/ — never fetch at runtime,
  // so the UI renders identically with zero connectivity.
  GoogleFonts.config.allowRuntimeFetching = false;

  // sqflite needs the FFI factory on desktop platforms.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    // Notifications unsupported on this platform — app still works.
    debugPrint('Notification init failed: $e');
  }

  // Cloud sync is optional: the app is fully usable offline and this
  // never blocks startup.
  await SyncService.initialize();

  // Reads the app version and flushes any feedback queued while offline.
  // Runs after Supabase is set up; never blocks startup.
  await FeedbackService.instance.initialize();

  runApp(const PoultryApp());
}
