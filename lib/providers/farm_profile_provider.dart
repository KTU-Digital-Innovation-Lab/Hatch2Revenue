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
    final prefs = await SharedPreferences.getInstance();
    _profile = FarmProfile(
      farmName: prefs.getString('fp_farmName') ?? '',
      ownerName: prefs.getString('fp_ownerName') ?? '',
      location: prefs.getString('fp_location') ?? '',
      phone: prefs.getString('fp_phone') ?? '',
      email: prefs.getString('fp_email') ?? '',
      farmSize: prefs.getString('fp_farmSize') ?? '',
    );
    notifyListeners();
  }

  Future<void> save(FarmProfile profile) async {
    _profile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fp_farmName', profile.farmName);
    await prefs.setString('fp_ownerName', profile.ownerName);
    await prefs.setString('fp_location', profile.location);
    await prefs.setString('fp_phone', profile.phone);
    await prefs.setString('fp_email', profile.email);
    await prefs.setString('fp_farmSize', profile.farmSize);
    notifyListeners();
  }
}
