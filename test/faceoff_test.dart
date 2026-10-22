import 'dart:convert';
import 'dart:math';

import 'package:albumrank/data/album_repository.dart';
import 'package:albumrank/data/settings_controller.dart';
import 'package:albumrank/logic/faceoff.dart';
import 'package:albumrank/main.dart';
import 'package:albumrank/models/album.dart';
import 'package:albumrank/services/album_lookup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Album _a(String id, double rating, {String artist = 'Band', int year = 2000, String genre = 'Metal'}) => Album(
      id: id,
      title: 'Album $id',
      artist: artist,
      year: year,
      genre: genre,
      rating: rating,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('match rules', () {
    test('tied, within ½ and any', () {
      final a = _a('a', 7), b = _a('b', 7), c = _a('c', 7.5), d = _a('d', 8.5);
      expect(FaceOffMatch.tied.allows(a, b), isTrue);
      expect(FaceOffMatch.tied.allows(a, c), isFalse);
      expect(FaceOffMatch.close.allows(a, c), isTrue);
      expect(FaceOffMatch.close.allows(a, d), isFalse);
      expect(FaceOffMatch.any.allows(a, d), isTrue);
    });

    test('pool filters by scope and ratings; counts match-ups', () {
      final albums = [
        _a('1', 7, artist: 'X'),
        _a('2', 7, artist: 'x '),
        _a('3', 7, artist: 'Y'),
        _a('4', 8, artist: 'X'),
      ];
      expect(faceOffPool(albums, scope: FaceOffScope.artist, scopeValue: 'X').map((a) => a.id), ['1', '2', '4']);
      expect(faceOffPool(albums, ratings: {7}).length, 3);
      expect(countMatchUps(faceOffPool(albums), FaceOffMatch.tied), 3);
      expect(countMatchUps(faceOffPool(albums), FaceOffMatch.any), 6);
    });
  });

  group('rating options', () {
    test('tie offers raise winner or lower loser', () {
      final o = faceOffOptions(_a('w', 7), _a('l', 7));
      expect(o.map((x) => x.changes), [
        {'w': 7.5},
        {'l': 6.5},
      ]);
    });

    test('upset also offers both', () {
      final o = faceOffOptions(_a('w', 6), _a('l', 8));
      expect(o.map((x) => x.changes), [
        {'w': 6.5},
        {'l': 7.5},
        {'w': 6.5, 'l': 7.5},
      ]);
    });

    test('nothing to change when ratings already agree', () {
      expect(faceOffOptions(_a('w', 8), _a('l', 7)), isEmpty);
    });

    test('respects the 1 and 10 limits', () {
      expect(faceOffOptions(_a('w', 10), _a('l', 10)).map((x) => x.changes), [
        {'l': 9.5},
      ]);
      expect(faceOffOptions(_a('w', 1), _a('l', 1)).map((x) => x.changes), [
        {'w': 1.5},
      ]);
    });
  });

  group('session', () {
    test('never repeats a pair and stops when out of pairs', () {
      final albums = [_a('a', 7), _a('b', 7), _a('c', 7), _a('d', 7)];
      final s = FaceOffSession(albums, FaceOffMatch.tied, random: Random(1));
      final seen = <String>{};
      while (true) {
        final pair = s.next(albums);
        if (pair == null) break;
        final key = ([pair.$1.id, pair.$2.id]..sort()).join();
        expect(seen.add(key), isTrue, reason: 'repeated $key');
        s.record(pair.$1, pair.$2, pair.$1.id);
      }
      expect(seen.length, 6);
    });

    test('respects rounds and uses live ratings', () {
      final albums = [_a('a', 7), _a('b', 7), _a('c', 7)];
      final s = FaceOffSession(albums, FaceOffMatch.tied, rounds: 1, random: Random(2));
      final pair = s.next(albums)!;
      s.record(pair.$1, pair.$2, pair.$1.id);
      expect(s.roundsDone, isTrue);
      expect(s.next(albums), isNull);

      final live = [_a('a', 7), _a('b', 8), _a('c', 9)];
      expect(FaceOffSession(live, FaceOffMatch.tied).next(live), isNull);
    });
  });

  test('wins and losses survive a JSON round trip; old backups still load', () {
    final a = _a('a', 7).copyWith(wins: 3, losses: 1);
    final back = Album.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
    expect((back.wins, back.losses), (3, 1));
    final old = _a('b', 7).toJson();
    expect(old.containsKey('wins'), isFalse);
    final loaded = Album.fromJson(old);
    expect((loaded.wins, loaded.losses), (0, 0));
  });

  group('arena', () {
    Future<AlbumRepository> pumpApp(WidgetTester tester, List<(String, num)> albums) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = AlbumRepository(prefs);
      await repo.importJson(jsonEncode({
        'app': 'AlbumRank',
        'schemaVersion': 1,
        'albums': [
          for (final (i, (title, rating)) in albums.indexed)
            {'id': '$i', 'title': title, 'artist': 'Artist $i', 'year': 2000 + i, 'genre': 'Metal', 'rating': rating,
              'createdAt': '2026-01-01T00:00:00.000', 'updatedAt': '2026-01-01T00:00:00.000'},
        ],
      }));
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await tester.pumpWidget(AlbumRankerApp(
        repository: repo,
        settings: SettingsController(prefs),
        lookup: AlbumLookupService(client: MockClient((_) async => http.Response('{"results":[]}', 200))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Face-off'));
      await tester.pumpAndSettle();
      return repo;
    }

    Future<void> start(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('faceoff-start')));
      await tester.tap(find.byKey(const ValueKey('faceoff-start')));
      await tester.pumpAndSettle();
    }

    testWidgets('pick a winner, apply a rating change, see the recap', (tester) async {
      final repo = await pumpApp(tester, [('One', 7), ('Two', 7)]);
      expect(find.byKey(const ValueKey('faceoff-count')), findsOneWidget);
      await start(tester);

      expect(find.byKey(const ValueKey('fighter-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('fighter-right')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fighter-left')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('winner-crown')), findsOneWidget);

      final winner = repo.albums.firstWhere((a) => a.wins == 1);
      final loser = repo.albums.firstWhere((a) => a.losses == 1);
      expect(winner.id, isNot(loser.id));

      await tester.tap(find.byKey(const ValueKey('faceoff-option-0')));
      await tester.pumpAndSettle();
      expect(repo.byId(winner.id)!.rating, 7.5);
      expect(find.textContaining('Raised'), findsOneWidget);

      // Only one pair exists, so the next step is the recap.
      await tester.tap(find.byKey(const ValueKey('faceoff-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recap')), findsOneWidget);
      expect(find.textContaining('7 → 7.5'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recap-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('faceoff-start')), findsOneWidget);
    });

    testWidgets('keep ratings and too close leave ratings alone', (tester) async {
      final repo = await pumpApp(tester, [('One', 7), ('Two', 7), ('Three', 7)]);
      await start(tester);

      await tester.tap(find.byKey(const ValueKey('fighter-right')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('faceoff-keep')));
      await tester.pumpAndSettle();
      expect(repo.albums.every((a) => a.rating == 7), isTrue);
      expect(repo.albums.fold<int>(0, (n, a) => n + a.wins), 1);

      await tester.tap(find.byKey(const ValueKey('faceoff-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('faceoff-too-close')));
      await tester.pumpAndSettle();
      expect(repo.albums.fold<int>(0, (n, a) => n + a.wins), 1);
      expect(repo.albums.fold<int>(0, (n, a) => n + a.losses), 1);

      await tester.tap(find.byKey(const ValueKey('faceoff-finish')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recap-summary')), findsOneWidget);
    });

    testWidgets('album screen shows the face-off record', (tester) async {
      final repo = await pumpApp(tester, [('One', 7), ('Two', 7)]);
      await repo.recordFaceOff(winnerId: '0', loserId: '1');
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('faceoff-record')), findsOneWidget);
      expect(find.textContaining('1–0'), findsOneWidget);
    });
  });
}
