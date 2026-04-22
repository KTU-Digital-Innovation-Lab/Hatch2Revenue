import 'package:flutter/foundation.dart';

/// Simple notifier for quick actions that require showing dialogs on other screens.
class QuickActionProvider extends ChangeNotifier {
  String? _action;

  String? get action => _action;

  void trigger(String actionName) {
    _action = actionName;
    notifyListeners();
  }

  void clear() {
    _action = null;
  }
}
