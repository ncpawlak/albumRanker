import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/album.dart';

class DuplicateAlbumException implements Exception {
  DuplicateAlbumException(this.existing);
  final Album existing;
}

/// Lower-cased with spacing collapsed, so "Born Of Osiris" == "born of  osiris".
String normalizeName(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

enum NameField {
  artist('Artist'),
  genre('Genre');

  const NameField(this.label);
  final String label;

  String of(Album a) => this == artist ? a.artist : a.genre;
}

/// One artist or genre that appears with several spellings.
class NameVariants {
  const NameVariants(this.field, this.spellings);

  final NameField field;

  /// Most-used spelling first.
  final List<({String spelling, int count})> spellings;

  String get preferred => spellings.first.spelling;
  int get albumCount => spellings.fold(0, (s, e) => s + e.count);
}

/// Holds the master album list and persists it as versioned JSON.
///
/// Stored shape: `{"schemaVersion": N, "albums": [...]}`. When fields are added
/// later, bump [schemaVersion] and add a step to [_migrate] so older data loads.
class AlbumRepository extends ChangeNotifier {
  AlbumRepository(this._prefs) {
    _load();
  }

  static const int schemaVersion = 1;
  static const String storageKey = 'albumrank.library';

  /// Tags backups so files from sibling *Rank apps aren't imported by mistake.
  static const String appId = 'AlbumRank';

  final SharedPreferences _prefs;
  final List<Album> _albums = [];
  final Random _random = Random();

  List<Album> get albums => List.unmodifiable(_albums);

  /// Distinct genres in use, sorted alphabetically (for suggestions).
  List<String> get genres {
    final seen = <String, String>{};
    for (final a in _albums) {
      seen.putIfAbsent(a.genre.toLowerCase(), () => a.genre);
    }
    return seen.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Album? byId(String id) {
    for (final a in _albums) {
      if (a.id == id) return a;
    }
    return null;
  }

  Album? findDuplicate(String title, String artist, {String? excludeId}) {
    final key = Album.makeDuplicateKey(title, artist);
    for (final a in _albums) {
      if (a.id != excludeId && a.duplicateKey == key) return a;
    }
    return null;
  }

  Future<Album> add({
    required String title,
    required String artist,
    required int year,
    required String genre,
    required double rating,
    String? artworkUrl,
    String? externalId,
  }) async {
    final dup = findDuplicate(title, artist);
    if (dup != null) throw DuplicateAlbumException(dup);
    final now = DateTime.now();
    final album = Album(
      id: _newId(),
      title: title.trim(),
      artist: _existingSpelling(NameField.artist, artist) ?? artist.trim(),
      year: year,
      genre: _existingSpelling(NameField.genre, genre) ?? genre.trim(),
      rating: rating,
      artworkUrl: artworkUrl,
      externalId: externalId,
      createdAt: now,
      updatedAt: now,
    );
    _albums.add(album);
    await _save();
    return album;
  }

  /// Saves [album]. A name that matches another album's artist or genre apart
  /// from capitalization/spacing takes that existing spelling, so one artist
  /// never splits in two. Changing only the capitalization of this album's own
  /// artist or genre is treated as a correction and applied everywhere.
  Future<void> update(Album album) async {
    final dup = findDuplicate(album.title, album.artist, excludeId: album.id);
    if (dup != null) throw DuplicateAlbumException(dup);
    final i = _albums.indexWhere((a) => a.id == album.id);
    if (i < 0) throw StateError('Album ${album.id} not found');
    final old = _albums[i];
    String resolve(NameField field) {
      final typed = field.of(album).trim();
      final before = field.of(old);
      if (typed != before && normalizeName(typed) == normalizeName(before)) {
        _renameAll(field, typed);
        return typed;
      }
      return _existingSpelling(field, typed, excludeId: album.id) ?? typed;
    }

    final artist = resolve(NameField.artist);
    final genre = resolve(NameField.genre);
    _albums[i] = album.copyWith(
      title: album.title.trim(),
      artist: artist,
      genre: genre,
      updatedAt: DateTime.now(),
    );
    await _save();
  }

  /// Adds a face-off win and loss to the two albums' head-to-head records.
  Future<void> recordFaceOff({required String winnerId, required String loserId}) async {
    for (var i = 0; i < _albums.length; i++) {
      final a = _albums[i];
      if (a.id == winnerId) _albums[i] = a.copyWith(wins: a.wins + 1);
      if (a.id == loserId) _albums[i] = a.copyWith(losses: a.losses + 1);
    }
    await _save();
  }

  /// Sets several ratings at once (album id → rating), e.g. after a face-off.
  Future<void> setRatings(Map<String, double> ratings) async {
    final now = DateTime.now();
    for (var i = 0; i < _albums.length; i++) {
      final r = ratings[_albums[i].id];
      if (r != null && Album.isValidRating(r)) _albums[i] = _albums[i].copyWith(rating: r, updatedAt: now);
    }
    await _save();
  }

  /// Artists and genres that are spelled more than one way, e.g.
  /// "BABYMETAL" and "Babymetal". Each entry's spellings are most-used first.
  List<NameVariants> nameVariants() {
    final result = <NameVariants>[];
    for (final field in NameField.values) {
      final groups = <String, Map<String, int>>{};
      for (final a in _albums) {
        final name = field.of(a);
        final counts = groups.putIfAbsent(normalizeName(name), () => {});
        counts[name] = (counts[name] ?? 0) + 1;
      }
      for (final counts in groups.values) {
        if (counts.length < 2) continue;
        final spellings = counts.entries.toList()
          ..sort((a, b) {
            final c = b.value.compareTo(a.value);
            return c != 0 ? c : a.key.compareTo(b.key);
          });
        result.add(NameVariants(field, [for (final e in spellings) (spelling: e.key, count: e.value)]));
      }
    }
    result.sort((a, b) {
      final f = a.field.index.compareTo(b.field.index);
      return f != 0 ? f : a.preferred.toLowerCase().compareTo(b.preferred.toLowerCase());
    });
    return result;
  }

  /// Renames every album whose [field] matches [keep] (ignoring case/spacing)
  /// to exactly [keep]. Returns how many albums changed.
  Future<int> mergeName(NameField field, String keep) async {
    final changed = _renameAll(field, keep);
    if (changed > 0) await _save();
    return changed;
  }

  int _renameAll(NameField field, String keep) {
    final key = normalizeName(keep);
    var changed = 0;
    final now = DateTime.now();
    for (var i = 0; i < _albums.length; i++) {
      final a = _albums[i];
      final name = field.of(a);
      if (name == keep || normalizeName(name) != key) continue;
      _albums[i] = field == NameField.artist
          ? a.copyWith(artist: keep, updatedAt: now)
          : a.copyWith(genre: keep, updatedAt: now);
      changed++;
    }
    return changed;
  }

  /// The most-used existing spelling of [name] in [field], if any album uses one.
  String? _existingSpelling(NameField field, String name, {String? excludeId}) {
    final key = normalizeName(name);
    final counts = <String, int>{};
    for (final a in _albums) {
      if (a.id == excludeId) continue;
      final n = field.of(a);
      if (normalizeName(n) == key) counts[n] = (counts[n] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  Future<void> delete(String id) async {
    _albums.removeWhere((a) => a.id == id);
    await _save();
  }

  /// Re-inserts a previously deleted album (used by "Undo").
  Future<void> restore(Album album) async {
    if (byId(album.id) != null) return;
    _albums.add(album);
    await _save();
  }

  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(_envelope());
  }

  /// Replaces the whole library with the contents of a backup file.
  /// Returns the number of albums imported. Throws [FormatException] if invalid.
  Future<int> importJson(String source) async {
    final parsed = _parse(jsonDecode(source));
    final unique = <String, Album>{};
    for (final a in parsed) {
      unique.putIfAbsent(a.duplicateKey, () => a);
    }
    _albums
      ..clear()
      ..addAll(unique.values);
    await _save();
    return _albums.length;
  }

  void _load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;
    try {
      _albums.addAll(_parse(jsonDecode(raw)));
    } catch (e) {
      debugPrint('Failed to load library: $e');
    }
  }

  List<Album> _parse(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Not an AlbumRank backup');
    }
    final version = (decoded['schemaVersion'] as num?)?.toInt();
    final list = decoded['albums'];
    final app = decoded['app'];
    if (app != null && app != appId) {
      throw FormatException('This is a $app backup, not an $appId backup');
    }
    if (version == null || list is! List) {
      throw const FormatException('Not an AlbumRank backup');
    }
    if (version > schemaVersion) {
      throw FormatException('Backup is from a newer app version ($version)');
    }
    try {
      final migrated = _migrate(version, list.cast<Map<String, dynamic>>());
      return migrated.map(Album.fromJson).toList();
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Backup contains an invalid album: $e');
    }
  }

  List<Map<String, dynamic>> _migrate(int fromVersion, List<Map<String, dynamic>> albums) {
    // Add migration steps here as the schema grows, e.g.:
    // if (fromVersion < 2) albums = [for (final a in albums) {...a, 'newField': defaultValue}];
    return albums;
  }

  Map<String, dynamic> _envelope() => {
        'app': appId,
        'schemaVersion': schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'albums': _albums.map((a) => a.toJson()).toList(),
      };

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(storageKey, jsonEncode(_envelope()));
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(1 << 30).toRadixString(36)}';
}
