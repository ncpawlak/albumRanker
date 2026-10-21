import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs)
      : _themeMode = _prefs.getString(_themeKey) == 'light' ? ThemeMode.light : ThemeMode.dark;

  static const _themeKey = 'album_ranker.theme';

  final SharedPreferences _prefs;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode == ThemeMode.light ? 'light' : 'dark');
  }
}
