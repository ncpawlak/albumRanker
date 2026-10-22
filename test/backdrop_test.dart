import 'dart:convert';

import 'package:albumrank/data/album_repository.dart';
import 'package:albumrank/data/settings_controller.dart';
import 'package:albumrank/logic/ranking.dart';
import 'package:albumrank/main.dart';
import 'package:albumrank/services/album_lookup_service.dart';
import 'package:albumrank/services/artist_image_service.dart';
import 'package:albumrank/ui/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _photo = 'https://cdn-images.dzcdn.net/images/artist/abc/1000x1000-000000-80-0-0.jpg';
const _other = 'https://cdn-images.dzcdn.net/images/artist/def/1000x1000-000000-80-0-0.jpg';
const _silhouette = 'https://cdn-images.dzcdn.net/images/artist//1000x1000-000000-80-0-0.jpg';

Map<String, Object> _artist(String name, String pic, {int fans = 1000}) =>
    {'name': name, 'picture_xl': pic, 'picture_medium': pic, 'nb_fan': fans};

/// Fake Deezer: answers by query; counts requests.
MockClient _deezer(Map<String, List<Map<String, Object>>> byQuery, {List<String>? log, bool fail = false}) =>
    MockClient((req) async {
      final q = req.url.queryParameters['q'] ?? '';
      log?.add(q);
      if (fail) throw http.ClientException('offline');
      return http.Response(jsonEncode({'data': byQuery[q] ?? const []}), 200);
    });

void main() {
  group('ArtistImageService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('matches names loosely, caches the result and only looks up once', () async {
      final prefs = await SharedPreferences.getInstance();
      final log = <String>[];
      final s = ArtistImageService(prefs,
          client: _deezer({
            'Polaris': [_artist('polaris.', _photo)],
          }, log: log));
      expect(await s.resolve('Polaris'), _photo);
      expect(await s.resolve('  polaris '), _photo);
      expect(log, ['Polaris']);
      expect(ArtistImageService(prefs).imageFor('POLARIS'), _photo, reason: 'saved in prefs');
    });

    test('no exact match or only a silhouette means no image, remembered', () async {
      final prefs = await SharedPreferences.getInstance();
      final log = <String>[];
      final s = ArtistImageService(prefs,
          client: _deezer({
            'The Amkty Affliction': [_artist('The Amity Affliction', _photo)],
            'Nobody': [_artist('Nobody', _silhouette)],
          }, log: log));
      expect(await s.resolve('The Amkty Affliction'), isNull);
      expect(await s.resolve('Nobody'), isNull);
      expect(s.isKnown('Nobody'), isTrue);
      await s.resolve('Nobody');
      expect(log.length, 2);
    });

    test('network errors are not remembered', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = ArtistImageService(prefs, client: _deezer({}, fail: true));
      expect(await s.resolve('Korn'), isNull);
      expect(s.isKnown('Korn'), isFalse);
    });

    test('setImage overrides and clears', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = ArtistImageService(prefs, client: _deezer({}));
      await s.setImage('Korn', _other);
      expect(s.imageFor('korn'), _other);
      await s.setImage('Korn', null);
      expect(s.imageFor('korn'), isNull);
      expect(s.isKnown('korn'), isTrue);
    });
  });

  group('UI', () {
    late AlbumRepository repo;
    late SettingsController settings;

    Future<void> pumpApp(WidgetTester tester, MockClient deezer) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = AlbumRepository(prefs);
      settings = SettingsController(prefs);
      await repo.importJson(jsonEncode({
        'app': 'AlbumRank',
        'schemaVersion': 1,
        'albums': [
          for (final (i, (title, artist, rating)) in [
            ('One', 'Sleep Token', 8),
            ('Two', 'Sleep Token', 8),
            ('Three', 'Polaris', 7),
          ].indexed)
            {'id': '$i', 'title': title, 'artist': artist, 'year': 2020 + i, 'genre': 'Rock', 'rating': rating,
              'createdAt': '2026-01-01T00:00:00.000', 'updatedAt': '2026-01-01T00:00:00.000'},
        ],
      }));
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await tester.pumpWidget(AlbumRankerApp(
        repository: repo,
        settings: settings,
        lookup: AlbumLookupService(client: MockClient((_) async => http.Response('{"results":[]}', 200))),
        artistImages: ArtistImageService(prefs, client: deezer),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> openArtist(WidgetTester tester, String artist) async {
      final key = rankGroups(repo.albums, GroupBy.artist).firstWhere((g) => g.label == artist).key;
      tester.state<NavigatorState>(find.byType(Navigator).first).push(
          MaterialPageRoute(builder: (_) => GroupDetailScreen(groupBy: GroupBy.artist, groupKey: key)));
      await tester.pumpAndSettle();
    }

    testWidgets('artist screen shows the band photo, and the setting turns it off', (tester) async {
      await pumpApp(tester, _deezer({'Sleep Token': [_artist('Sleep Token', _photo)]}));
      await openArtist(tester, 'Sleep Token');
      final backdrop = find.byKey(const ValueKey('group-backdrop'));
      expect(backdrop, findsOneWidget);
      expect(
          find.descendant(of: backdrop, matching: find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage
              && (w.image as NetworkImage).url == _photo)),
          findsOneWidget);

      await settings.setBackgrounds(false);
      await tester.pumpAndSettle();
      expect(backdrop, findsNothing);
      expect(find.byKey(const ValueKey('change-image')), findsNothing);
    });

    testWidgets('change image re-searches and saves the pick', (tester) async {
      await pumpApp(
          tester,
          _deezer({
            'Polaris': [_artist('polaris.', _photo)],
            'Polaris band': [_artist('Polaris', _other, fans: 2500000), _artist('Polaris AU', _photo)],
          }));
      await openArtist(tester, 'Polaris');
      await tester.tap(find.byKey(const ValueKey('change-image')));
      await tester.pumpAndSettle();
      expect(find.text('Background for Polaris'), findsOneWidget);
      expect(find.byKey(const ValueKey('image-option-0')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('image-search-field')), 'Polaris band');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.text('2.5M fans on Deezer'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('image-option-0')));
      await tester.pumpAndSettle();

      final service = ArtistImageService(await SharedPreferences.getInstance());
      expect(service.imageFor('Polaris'), _other);
    });

    testWidgets('face-off shows both artists split diagonally', (tester) async {
      await pumpApp(tester, _deezer({'Sleep Token': [_artist('Sleep Token', _photo)]}));
      await tester.tap(find.text('Face-off'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('faceoff-start')));
      await tester.tap(find.byKey(const ValueKey('faceoff-start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('split-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('split-right')), findsOneWidget);
    });
  });
}
