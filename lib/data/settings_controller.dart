import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/ranking.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs)
      : _themeMode = _prefs.getString(_themeKey) == 'light' ? ThemeMode.light : ThemeMode.dark,
        _qualityCoefficient = _prefs.getBool(_qualityKey) ?? false,
        _groupSort = AlbumSort.fromName(_prefs.getString(_groupSortKey)),
        _chartCondensed = _prefs.getBool(_chartCondensedKey) ?? false,
        _backgrounds = _prefs.getBool(_backgroundsKey) ?? true;

  static const _themeKey = 'albumrank.theme';
  static const _qualityKey = 'albumrank.qualityCoefficient';
  static const _groupSortKey = 'albumrank.groupSort';
  static const _chartCondensedKey = 'albumrank.chartCondensed';
  static const _backgroundsKey = 'albumrank.backgrounds';

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  bool _qualityCoefficient;
  AlbumSort _groupSort;
  bool _chartCondensed;
  bool _backgrounds;

  /// Faint band photos / cover collages behind group screens and face-offs.
  bool get backgrounds => _backgrounds;

  Future<void> setBackgrounds(bool value) async {
    if (value == _backgrounds) return;
    _backgrounds = value;
    notifyListeners();
    await _prefs.setBool(_backgroundsKey, value);
  }

  ThemeMode get themeMode => _themeMode;

  /// Last sort picked on a group's detail screen.
  AlbumSort get groupSort => _groupSort;

  /// Fit the whole ratings-by-year chart on screen instead of scrolling it.
  bool get chartCondensed => _chartCondensed;

  Future<void> setGroupSort(AlbumSort value) async {
    if (value == _groupSort) return;
    _groupSort = value;
    notifyListeners();
    await _prefs.setString(_groupSortKey, value.name);
  }

  Future<void> setChartCondensed(bool value) async {
    if (value == _chartCondensed) return;
    _chartCondensed = value;
    notifyListeners();
    await _prefs.setBool(_chartCondensedKey, value);
  }

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
