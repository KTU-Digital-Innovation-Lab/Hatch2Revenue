import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);
  @override
  String toString() => message;
}

/// A small weather snapshot for the local farm, plus a read of what the
/// temperature means for laying.
class WeatherData {
  final double tempC;
  final double? humidity;
  final double todayMaxC;
  final double todayMinC;
  final double? tomorrowMaxC;
  final DateTime fetchedAt;

  WeatherData({
    required this.tempC,
    required this.humidity,
    required this.todayMaxC,
    required this.todayMinC,
    required this.tomorrowMaxC,
    required this.fetchedAt,
  });

  /// Heat / cold risk to egg laying. Layers are most comfortable around
  /// 18-24 C; output falls as heat climbs past the high 20s, and hard
  /// cold also hurts. Returns null when conditions look fine.
  ({String level, String message})? layingRisk() {
    final peak =
        (tomorrowMaxC != null && tomorrowMaxC! > todayMaxC) ? tomorrowMaxC! : todayMaxC;
    if (peak >= 35) {
      return (
        level: 'high',
        message:
            'Extreme heat (up to ${peak.toStringAsFixed(0)}°C) can sharply cut '
            'laying and raise deaths. Give plenty of cool water, shade and '
            'ventilation, and feed during the cooler hours.',
      );
    }
    if (peak >= 30) {
      return (
        level: 'watch',
        message:
            'Hot weather (up to ${peak.toStringAsFixed(0)}°C) can lower egg '
            'output. Keep water cool and plentiful and improve airflow in the house.',
      );
    }
    if (todayMinC <= 10) {
      return (
        level: 'watch',
        message:
            'Cold nights (down to ${todayMinC.toStringAsFixed(0)}°C) can stress '
            'the flock and dip laying. Keep the house draught-free and warm.',
      );
    }
    return (
      level: 'good',
      message:
          'Temperatures are in a comfortable range for layers — good for steady egg production.',
    );
  }
}

class WeatherService {
  /// Gets the device location (asking permission if needed) and fetches
  /// current conditions from Open-Meteo, a free service that needs no
  /// account or API key. Throws [WeatherException] with a plain message
  /// the UI can show.
  static Future<WeatherData> fetch() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw WeatherException('Turn on location to get your local weather.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw WeatherException(
          'Location permission is needed to show local weather.');
    }

    Position? pos = await Geolocator.getLastKnownPosition();
    pos ??= await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${pos.latitude}&longitude=${pos.longitude}'
      '&current=temperature_2m,relative_humidity_2m'
      '&daily=temperature_2m_max,temperature_2m_min'
      '&forecast_days=2&timezone=auto',
    );

    final http.Response res;
    try {
      res = await http.get(url).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw WeatherException('Could not reach the weather service. Check your internet.');
    }
    if (res.statusCode != 200) {
      throw WeatherException('Weather service is unavailable right now.');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>;
    final daily = j['daily'] as Map<String, dynamic>;
    final maxes = (daily['temperature_2m_max'] as List);
    final mins = (daily['temperature_2m_min'] as List);

    double d(dynamic v) => (v as num).toDouble();

    return WeatherData(
      tempC: d(cur['temperature_2m']),
      humidity: cur['relative_humidity_2m'] == null
          ? null
          : d(cur['relative_humidity_2m']),
      todayMaxC: d(maxes[0]),
      todayMinC: d(mins[0]),
      tomorrowMaxC: maxes.length > 1 ? d(maxes[1]) : null,
      fetchedAt: DateTime.now(),
    );
  }
}
