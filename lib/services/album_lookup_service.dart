import 'dart:convert';

import 'package:http/http.dart' as http;

class AlbumSuggestion {
  const AlbumSuggestion({
    required this.title,
    required this.artist,
    this.year,
    this.genre,
    this.artworkUrl,
    this.externalId,
  });

  final String title;
  final String artist;
  final int? year;
  final String? genre;
  final String? artworkUrl;
  final String? externalId;
}

/// Looks up albums using Apple's free iTunes Search API (no key required).
class AlbumLookupService {
  AlbumLookupService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AlbumSuggestion>> search(String term, {int limit = 8}) async {
    final query = term.trim();
    if (query.length < 2) return const [];
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': query,
      'media': 'music',
      'entity': 'album',
      'limit': '$limit',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw http.ClientException('Lookup failed (${response.statusCode})', uri);
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final results = (body['results'] as List? ?? const []).cast<Map<String, dynamic>>();
    return results
        .where((r) => r['collectionName'] is String && r['artistName'] is String)
        .map(_toSuggestion)
        .toList();
  }

  static AlbumSuggestion _toSuggestion(Map<String, dynamic> r) {
    final release = r['releaseDate'] as String?;
    final artwork = r['artworkUrl100'] as String?;
    return AlbumSuggestion(
      title: r['collectionName'] as String,
      artist: r['artistName'] as String,
      year: release != null && release.length >= 4 ? int.tryParse(release.substring(0, 4)) : null,
      genre: r['primaryGenreName'] as String?,
      artworkUrl: artwork?.replaceFirst('100x100bb', '600x600bb'),
      externalId: r['collectionId'] != null ? 'itunes:${r['collectionId']}' : null,
    );
  }
}
