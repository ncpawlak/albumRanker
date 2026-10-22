import 'dart:convert';

import 'package:albumrank/services/album_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses iTunes album results', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'resultCount': 2,
          'results': [
            {
              'collectionId': 1097861387,
              'collectionName': 'OK Computer',
              'artistName': 'Radiohead',
              'releaseDate': '1997-05-21T07:00:00Z',
              'primaryGenreName': 'Alternative',
              'artworkUrl100': 'https://example.com/100x100bb.jpg',
            },
            {'wrapperType': 'junk'},
          ],
        })),
        200,
      );
    });

    final results = await AlbumLookupService(client: client).search('ok computer');
    expect(requested.queryParameters['entity'], 'album');
    expect(results, hasLength(1));
    final r = results.single;
    expect(r.title, 'OK Computer');
    expect(r.artist, 'Radiohead');
    expect(r.year, 1997);
    expect(r.genre, 'Alternative');
    expect(r.artworkUrl, 'https://example.com/600x600bb.jpg');
    expect(r.externalId, 'itunes:1097861387');
  });

  test('short queries skip the network', () async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    });
    expect(await AlbumLookupService(client: client).search('a'), isEmpty);
    expect(called, isFalse);
  });

  test('non-200 responses throw', () async {
    final client = MockClient((_) async => http.Response('nope', 503));
    expect(AlbumLookupService(client: client).search('radiohead'), throwsA(isA<http.ClientException>()));
  });
}
