import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs)
      : _themeMode = _prefs.getString(_themeKey) == 'light' ? ThemeMode.light : ThemeMode.dark,
        _qualityCoefficient = _prefs.getBool(_qualityKey) ?? false;

  static const _themeKey = 'albumrank.theme';
  static const _qualityKey = 'albumrank.qualityCoefficient';

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  bool _qualityCoefficient;

  ThemeMode get themeMode => _themeMode;

  /// Rank groups by quality score (1 decimal) instead of whole-number average.
  bool get qualityCoefficient => _qualityCoefficient;

  Future<void> setQualityCoefficient(bool value) async {
    if (value == _qualityCoefficient) return;
    _qualityCoefficient = value;
    notifyListeners();
    await _prefs.setBool(_qualityKey, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode == ThemeMode.light ? 'light' : 'dark');
  }
}
