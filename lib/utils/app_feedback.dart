import 'package:flutter/material.dart';

/// Global messenger so non-widget code (providers, services) can
/// surface problems to the user instead of failing silently.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showAppError(String message) {
  try {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  } catch (_) {
    // No widget binding (e.g. unit tests) — nothing to show.
  }
}

void showAppMessage(String message) {
  try {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (_) {
    // No widget binding (e.g. unit tests) — nothing to show.
  }
}
