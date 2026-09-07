import 'package:flutter/foundation.dart';
import '../services/weather_service.dart';

/// Holds the latest local weather for the egg forecast. Nothing is
/// fetched until [load] is called, so no location is requested on
/// start-up — the farmer opts in from the egg screen.
class WeatherProvider extends ChangeNotifier {
  WeatherData? _data;
  bool _loading = false;
  String? _error;

  WeatherData? get data => _data;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _data != null;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await WeatherService.fetch();
    } catch (e) {
      _error = e is WeatherException ? e.message : 'Could not get the weather.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
