import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/album.dart';

class DuplicateAlbumException implements Exception {
  DuplicateAlbumException(this.existing);
  final Album existing;
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
    required int rating,
    String? artworkUrl,
    String? externalId,
  }) async {
    final dup = findDuplicate(title, artist);
    if (dup != null) throw DuplicateAlbumException(dup);
    final now = DateTime.now();
    final album = Album(
      id: _newId(),
      title: title.trim(),
      artist: artist.trim(),
      year: year,
      genre: genre.trim(),
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

  Future<void> update(Album album) async {
    final dup = findDuplicate(album.title, album.artist, excludeId: album.id);
    if (dup != null) throw DuplicateAlbumException(dup);
    final i = _albums.indexWhere((a) => a.id == album.id);
    if (i < 0) throw StateError('Album ${album.id} not found');
    _albums[i] = album.copyWith(
      title: album.title.trim(),
      artist: album.artist.trim(),
      genre: album.genre.trim(),
      updatedAt: DateTime.now(),
    );
    await _save();
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
