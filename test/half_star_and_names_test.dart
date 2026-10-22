import 'dart:convert';

import 'package:albumrank/data/album_repository.dart';
import 'package:albumrank/data/settings_controller.dart';
import 'package:albumrank/logic/ranking.dart';
import 'package:albumrank/logic/stats.dart';
import 'package:albumrank/main.dart';
import 'package:albumrank/models/album.dart';
import 'package:albumrank/services/album_lookup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ranking_test.dart' show album;
import 'test_helpers.dart';

Future<AlbumRepository> newRepo([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return AlbumRepository(await SharedPreferences.getInstance());
}

void main() {
  group('half stars', () {
    test('valid ratings are 1 to 10 in half steps', () {
      expect(Album.isValidRating(7.5), isTrue);
      expect(Album.isValidRating(1), isTrue);
      expect(Album.isValidRating(10), isTrue);
      expect(Album.isValidRating(0.5), isFalse);
      expect(Album.isValidRating(10.5), isFalse);
      expect(Album.isValidRating(7.25), isFalse);
    });

    test('formatRating drops .0', () {
      expect(formatRating(7), '7');
      expect(formatRating(7.0), '7');
      expect(formatRating(7.5), '7.5');
    });

    test('group averages stay whole numbers and round half up', () {
      // 7.5 + 8 = 15.5 / 2 = 7.75 -> 8; 7 + 7.5 = 7.25 -> 7; 6.5 alone -> 7.
      expect(roundedAverage(15.5, 2), 8);
      expect(roundedAverage(14.5, 2), 7);
      expect(roundedAverage(6.5, 1), 7);
      final groups = rankGroups([
        album('A', 'X', 2000, 'Rock', 7.5),
        album('B', 'X', 2001, 'Rock', 8),
        album('C', 'Y', 2000, 'Rock', 7),
        album('D', 'Y', 2001, 'Rock', 7.5),
      ], GroupBy.artist);
      expect([for (final g in groups) (g.label, g.average)], [('X', 8), ('Y', 7)]);
      expect(qualityTenthsFor(15.5, 2), 64); // (15.5 + 10) / 4 = 6.375
    });

    test('a half star breaks an album tie', () {
      final ranked = rankAlbums([album('A', 'X', 2000, 'Rock', 7), album('B', 'X', 2000, 'Rock', 7.5)]);
      expect([for (final r in ranked) (r.album.title, r.rank)], [('B', 1), ('A', 2)]);
    });

    test('stats spread has a bucket per half star', () {
      final s = LibraryStats.from([album('A', 'X', 2000, 'Rock', 7.5), album('B', 'X', 2000, 'Rock', 1)]);
      expect(s.distribution.length, 19);
      expect(s.distribution[13], 1); // 7.5
      expect(s.distribution[0], 1); // 1
      expect(LibraryStats.bucketRating(13), 7.5);
    });

    test('backups keep half stars and whole ratings stay ints', () async {
      final repo = await newRepo();
      await repo.add(title: 'A', artist: 'X', year: 2000, genre: 'Rock', rating: 7.5);
      await repo.add(title: 'B', artist: 'X', year: 2000, genre: 'Rock', rating: 8);
      final json = repo.exportJson();
      final ratings = [for (final a in (jsonDecode(json)['albums'] as List)) a['rating']];
      expect(ratings, [7.5, 8]);
      expect(ratings[1], isA<int>());
      final copy = await newRepo();
      await copy.importJson(json);
      expect([for (final a in copy.albums) a.rating], [7.5, 8.0]);
    });

    test('old whole-number backups still load', () async {
      final repo = await newRepo();
      final n = await repo.importJson(jsonEncode({
        'app': 'AlbumRank',
        'schemaVersion': 1,
        'albums': [
          {'id': 'a', 'title': 'T', 'artist': 'A', 'year': 2000, 'genre': 'G', 'rating': 9,
            'createdAt': '2026-01-01T00:00:00.000', 'updatedAt': '2026-01-01T00:00:00.000'},
        ],
      }));
      expect(n, 1);
      expect(repo.albums.single.rating, 9.0);
    });

    test('rejects off-step ratings', () async {
      final repo = await newRepo();
      expect(
        () => repo.importJson(jsonEncode({
          'app': 'AlbumRank',
          'schemaVersion': 1,
          'albums': [
            {'id': 'a', 'title': 'T', 'artist': 'A', 'year': 2000, 'genre': 'G', 'rating': 7.3,
              'createdAt': '2026-01-01T00:00:00.000', 'updatedAt': '2026-01-01T00:00:00.000'},
          ],
        })),
        throwsFormatException,
      );
    });
  });

  group('duplicate names', () {
    test('new albums reuse the existing artist and genre spelling', () async {
      final repo = await newRepo();
      await repo.add(title: 'A', artist: 'Bullet for My Valentine', year: 2005, genre: 'Metal', rating: 8);
      final b = await repo.add(title: 'B', artist: ' bullet FOR my  valentine', year: 2008, genre: 'metal', rating: 7);
      expect(b.artist, 'Bullet for My Valentine');
      expect(b.genre, 'Metal');
      expect(repo.nameVariants(), isEmpty);
    });

    test('lists names spelled several ways, most-used first, and merges them', () async {
      final repo = await newRepo();
      // Seed split spellings directly, as older versions allowed.
      await repo.importJson(jsonEncode({
        'app': 'AlbumRank',
        'schemaVersion': 1,
        'albums': [
          for (final (i, artist) in ['Babymetal', 'BABYMETAL', 'Babymetal', 'Trivium'].indexed)
            {'id': '$i', 'title': 'T$i', 'artist': artist, 'year': 2000, 'genre': 'Metal', 'rating': 7,
              'createdAt': '2026-01-01T00:00:00.000', 'updatedAt': '2026-01-01T00:00:00.000'},
        ],
      }));
      final v = repo.nameVariants();
      expect(v.length, 1);
      expect(v.single.field, NameField.artist);
      expect([for (final s in v.single.spellings) (s.spelling, s.count)], [('Babymetal', 2), ('BABYMETAL', 1)]);
      expect(rankGroups(repo.albums, GroupBy.artist).length, 2, reason: 'ranking already ignores case');

      expect(await repo.mergeName(NameField.artist, 'BABYMETAL'), 2);
      expect(repo.nameVariants(), isEmpty);
      expect(repo.albums.where((a) => a.artist == 'BABYMETAL').length, 3);
    });

    test('editing only the capitalization of an artist fixes it everywhere', () async {
      final repo = await newRepo();
      final a = await repo.add(title: 'A', artist: 'War Of Ages', year: 2001, genre: 'Metal', rating: 7);
      await repo.add(title: 'B', artist: 'War Of Ages', year: 2004, genre: 'Metal', rating: 6);
      await repo.update(a.copyWith(artist: 'War of Ages'));
      expect(repo.albums.map((x) => x.artist).toSet(), {'War of Ages'});
    });

    test('editing an album to a differently-cased existing artist joins it', () async {
      final repo = await newRepo();
      await repo.add(title: 'A', artist: 'Born of Osiris', year: 2009, genre: 'Metal', rating: 7);
      final b = await repo.add(title: 'B', artist: 'Someone', year: 2011, genre: 'Metal', rating: 6);
      await repo.update(b.copyWith(artist: 'BORN OF OSIRIS'));
      expect(repo.byId(b.id)!.artist, 'Born of Osiris');
    });
  });

  group('UI', () {
    Future<AlbumRepository> pumpApp(WidgetTester tester, {List<Map<String, Object>> albums = const []}) async {
      final repo = await newRepo();
      if (albums.isNotEmpty) {
        await repo.importJson(jsonEncode({'app': 'AlbumRank', 'schemaVersion': 1, 'albums': albums}));
      }
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await tester.pumpWidget(AlbumRankerApp(
        repository: repo,
        settings: SettingsController(await SharedPreferences.getInstance()),
        lookup: AlbumLookupService(client: MockClient((_) async => http.Response('{"results":[]}', 200))),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('the −/+ buttons step by half stars and the slider reaches the ends', (tester) async {
      final repo = await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('field-title')), 'Album');
      await tester.enterText(find.byKey(const ValueKey('field-artist')), 'Artist');
      await tester.enterText(find.byKey(const ValueKey('field-year')), '2020');
      await tester.enterText(find.byKey(const ValueKey('field-genre')), 'Metal');
      await tester.pump(const Duration(seconds: 1));
      expect(ratingText(tester), 'Not rated');
      final plus = find.byKey(const ValueKey('rating-plus'));
      final minus = find.byKey(const ValueKey('rating-minus'));
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.pump();
      expect(ratingText(tester), '6');
      await tester.tap(minus);
      await tester.pump();
      expect(ratingText(tester), '5.5');

      final slider = find.byKey(const ValueKey('rating-slider'));
      await tester.drag(slider, const Offset(600, 0));
      await tester.pump();
      expect(ratingText(tester), '10');
      expect(tester.widget<IconButton>(plus).onPressed, isNull, reason: 'cannot go above 10');
      await tester.drag(slider, const Offset(-600, 0));
      await tester.pump();
      expect(ratingText(tester), '1');

      await setRating(tester, 7.5);
      await tester.tap(find.byKey(const ValueKey('save-album')));
      await tester.pumpAndSettle();
      expect(repo.albums.single.rating, 7.5);
      expect(find.text('7.5'), findsOneWidget);
    });
    testWidgets('settings merges duplicate names', (tester) async {
      final repo = await pumpApp(tester, albums: [
        for (final (i, artist) in ['A Day to Remember', 'A Day To Remember', 'A Day to Remember'].indexed)
          {'id': '$i', 'title': 'T$i', 'artist': artist, 'year': 2000, 'genre': 'Rock', 'rating': 7,
            'createdAt': '2026-01-01T00:00:00.000', 'updatedAt': '2026-01-01T00:00:00.000'},
      ]);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('1 name is spelled more than one way'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('duplicate-names')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merge-all')));
      await tester.pumpAndSettle();
      expect(find.text('Every artist and genre is spelled one way'), findsOneWidget);
      expect(repo.albums.map((a) => a.artist).toSet(), {'A Day to Remember'});
    });
  });
}
