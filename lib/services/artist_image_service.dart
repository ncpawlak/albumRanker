import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ArtistImageOption {
  const ArtistImageOption({required this.name, required this.imageUrl, required this.thumbUrl, this.fans = 0});

  final String name;
  final String imageUrl;
  final String thumbUrl;
  final int fans;
}

/// Finds band photos with Deezer's free artist search (no key required) and
/// remembers each artist's photo so it is only looked up once.
class ArtistImageService extends ChangeNotifier {
  ArtistImageService(this._prefs, {http.Client? client}) : _client = client ?? http.Client() {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _cache.addAll((jsonDecode(raw) as Map<String, dynamic>).cast<String, String>());
      } catch (_) {}
    }
  }

  static const _key = 'albumrank.artistImages';

  final SharedPreferences _prefs;
  final http.Client _client;

  /// Normalized artist name -> image URL ('' = looked up, nothing found).
  final _cache = <String, String>{};
  final _pending = <String, Future<String?>>{};

  static String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  static String _loose(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool isKnown(String artist) => _cache.containsKey(_norm(artist));

  /// The saved photo for [artist], or null if none (yet).
  String? imageFor(String artist) {
    final url = _cache[_norm(artist)];
    return url == null || url.isEmpty ? null : url;
  }

  /// Looks up [artist]'s photo once and saves it. Network errors aren't saved,
  /// so the next visit tries again.
  Future<String?> resolve(String artist) {
    final key = _norm(artist);
    if (key.isEmpty) return Future.value(null);
    if (_cache.containsKey(key)) return Future.value(imageFor(artist));
    return _pending[key] ??= () async {
      try {
        final results = await search(artist, limit: 5);
        final want = _loose(artist);
        final match = results.where((r) => _loose(r.name) == want).firstOrNull;
        await _store(key, match?.imageUrl ?? '');
        return match?.imageUrl;
      } catch (_) {
        return null;
      } finally {
        _pending.remove(key);
      }
    }();
  }

  /// Deezer artists matching [term], most relevant first. Artists without a photo are skipped.
  Future<List<ArtistImageOption>> search(String term, {int limit = 12}) async {
    final query = term.trim();
    if (query.isEmpty) return const [];
    final uri = Uri.https('api.deezer.com', '/search/artist', {'q': query, 'limit': '$limit'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) throw http.ClientException('Artist search failed (${response.statusCode})', uri);
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final data = (body['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    return [
      for (final a in data)
        if (a['name'] is String && _hasPhoto(a['picture_xl']))
          ArtistImageOption(
            name: a['name'] as String,
            imageUrl: a['picture_xl'] as String,
            thumbUrl: (a['picture_medium'] ?? a['picture_xl']) as String,
            fans: (a['nb_fan'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  // Deezer returns a generic silhouette (empty hash in the path) for artists without a photo.
  static bool _hasPhoto(Object? url) => url is String && url.isNotEmpty && !url.contains('/artist//');

  /// Saves a chosen photo for [artist]; null means "no image".
  Future<void> setImage(String artist, String? url) => _store(_norm(artist), url ?? '');

  Future<void> _store(String key, String url) async {
    _cache[key] = url;
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(_cache));
  }
}
