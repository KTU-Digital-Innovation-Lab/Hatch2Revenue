import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';

/// Day / night mode. Persists the choice and keeps [AppColors.isDark]
/// in sync so the whole palette follows.
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'themeIsDark';

  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefKey) ?? false;
      AppColors.isDark = _isDark;
      notifyListeners();
    } catch (e) {
      debugPrint('ThemeProvider: prefs unavailable: $e');
    }
  }

  void toggle() {
    _isDark = !_isDark;
    AppColors.isDark = _isDark;
    notifyListeners();
    _saveAsync();
  }

  Future<void> _saveAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _isDark);
    } catch (e) {
      debugPrint('ThemeProvider: could not persist theme: $e');
    }
  }
}
