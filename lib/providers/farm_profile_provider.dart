import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/farm_profile.dart';

class FarmProfileProvider extends ChangeNotifier {
  FarmProfile _profile = const FarmProfile();
  FarmProfile get profile => _profile;

  FarmProfileProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _profile = FarmProfile(
        farmName: prefs.getString('fp_farmName') ?? '',
        ownerName: prefs.getString('fp_ownerName') ?? '',
        farmType: prefs.getString('fp_farmType') ?? '',
        farmSize: prefs.getString('fp_farmSize') ?? '',
        country: prefs.getString('fp_country') ?? '',
        region: prefs.getString('fp_region') ?? '',
        location: prefs.getString('fp_location') ?? '',
        phone: prefs.getString('fp_phone') ?? '',
        email: prefs.getString('fp_email') ?? '',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('FarmProfileProvider: prefs unavailable: $e');
    }
  }

  Future<void> save(FarmProfile profile) async {
    _profile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fp_farmName', profile.farmName);
    await prefs.setString('fp_ownerName', profile.ownerName);
    await prefs.setString('fp_farmType', profile.farmType);
    await prefs.setString('fp_farmSize', profile.farmSize);
    await prefs.setString('fp_country', profile.country);
    await prefs.setString('fp_region', profile.region);
    await prefs.setString('fp_location', profile.location);
    await prefs.setString('fp_phone', profile.phone);
    await prefs.setString('fp_email', profile.email);
    notifyListeners();
  }
}
