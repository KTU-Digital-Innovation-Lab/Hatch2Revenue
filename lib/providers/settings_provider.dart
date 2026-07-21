import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../utils/units.dart';

/// Personalisation: colour vision, readability, farm units, and start-up
/// behaviour. Keeps [AppColors] and [Units] in sync with the saved
/// choices so the whole app follows without any call-site changes.
class SettingsProvider extends ChangeNotifier {
  static const _kVision = 'set_visionMode';
  static const _kContrast = 'set_highContrast';
  static const _kTextScale = 'set_textScale';
  static const _kEggsPerCrate = 'set_eggsPerCrate';
  static const _kKgPerBag = 'set_kgPerBag';
  static const _kStartTab = 'set_startTab';
  static const _kReminderHour = 'set_reminderHour';

  ColorVisionMode _vision = ColorVisionMode.normal;
  bool _highContrast = false;
  double _textScale = 1.0;
  int _eggsPerCrate = Units.defaultEggsPerCrate;
  double _kgPerBag = Units.defaultKgPerBag;
  int _startTab = 0;
  int _reminderHour = 7;
  bool _loaded = false;

  ColorVisionMode get vision => _vision;
  bool get highContrast => _highContrast;
  double get textScale => _textScale;
  int get eggsPerCrate => _eggsPerCrate;
  double get kgPerBag => _kgPerBag;
  int get startTab => _startTab;
  int get reminderHour => _reminderHour;
  bool get loaded => _loaded;

  String get textScaleLabel => switch (_textScale) {
        < 1.0 => 'Small',
        < 1.15 => 'Normal',
        < 1.3 => 'Large',
        _ => 'Extra large',
      };

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _vision = ColorVisionMode
          .values[(p.getInt(_kVision) ?? 0).clamp(0, ColorVisionMode.values.length - 1)];
      _highContrast = p.getBool(_kContrast) ?? false;
      _textScale = p.getDouble(_kTextScale) ?? 1.0;
      _eggsPerCrate = p.getInt(_kEggsPerCrate) ?? Units.defaultEggsPerCrate;
      _kgPerBag = p.getDouble(_kKgPerBag) ?? Units.defaultKgPerBag;
      _startTab = p.getInt(_kStartTab) ?? 0;
      _reminderHour = p.getInt(_kReminderHour) ?? 7;
    } catch (e) {
      debugPrint('SettingsProvider: prefs unavailable: $e');
    }
    _apply();
    _loaded = true;
    notifyListeners();
  }

  /// Pushes the current settings into the global palette and units.
  void _apply() {
    AppColors.visionMode = _vision;
    AppColors.highContrast = _highContrast;
    Units.eggsPerCrate = _eggsPerCrate;
    Units.kgPerBag = _kgPerBag;
  }

  Future<void> _save(void Function(SharedPreferences p) write) async {
    try {
      final p = await SharedPreferences.getInstance();
      write(p);
    } catch (e) {
      debugPrint('SettingsProvider: could not persist setting: $e');
    }
  }

  void setVision(ColorVisionMode m) {
    _vision = m;
    _apply();
    notifyListeners();
    _save((p) => p.setInt(_kVision, m.index));
  }

  void setHighContrast(bool v) {
    _highContrast = v;
    _apply();
    notifyListeners();
    _save((p) => p.setBool(_kContrast, v));
  }

  void setTextScale(double v) {
    _textScale = v;
    notifyListeners();
    _save((p) => p.setDouble(_kTextScale, v));
  }

  void setEggsPerCrate(int v) {
    _eggsPerCrate = v.clamp(1, 120);
    _apply();
    notifyListeners();
    _save((p) => p.setInt(_kEggsPerCrate, _eggsPerCrate));
  }

  void setKgPerBag(double v) {
    _kgPerBag = v.clamp(1, 200);
    _apply();
    notifyListeners();
    _save((p) => p.setDouble(_kKgPerBag, _kgPerBag));
  }

  void setStartTab(int v) {
    _startTab = v;
    notifyListeners();
    _save((p) => p.setInt(_kStartTab, v));
  }

  void setReminderHour(int v) {
    _reminderHour = v.clamp(0, 23);
    notifyListeners();
    _save((p) => p.setInt(_kReminderHour, _reminderHour));
  }

  /// Restores every personalisation setting to its default.
  void resetAll() {
    _vision = ColorVisionMode.normal;
    _highContrast = false;
    _textScale = 1.0;
    _eggsPerCrate = Units.defaultEggsPerCrate;
    _kgPerBag = Units.defaultKgPerBag;
    _startTab = 0;
    _reminderHour = 7;
    _apply();
    notifyListeners();
    _save((p) {
      p.remove(_kVision);
      p.remove(_kContrast);
      p.remove(_kTextScale);
      p.remove(_kEggsPerCrate);
      p.remove(_kKgPerBag);
      p.remove(_kStartTab);
      p.remove(_kReminderHour);
    });
  }
}
