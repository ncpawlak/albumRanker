import 'dart:convert';

import 'package:albumrank/data/album_repository.dart';
import 'package:albumrank/data/settings_controller.dart';
import 'package:albumrank/main.dart';
import 'package:albumrank/services/album_lookup_service.dart';
import 'package:albumrank/ui/widgets/rating_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AlbumRepository> pumpApp(WidgetTester tester, List<(String, String, int, num)> albums) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = AlbumRepository(prefs);
    await repo.importJson(jsonEncode({
      'app': 'AlbumRank',
      'schemaVersion': 1,
      'albums': [
        for (final (i, (title, artist, year, rating)) in albums.indexed)
          {'id': '$i', 'title': title, 'artist': artist, 'year': year, 'genre': 'Metal', 'rating': rating,
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
    return repo;
  }

  test('cover placeholder initials skip "The" and use the first and last words', () {
    expect(AlbumCover.initials('The Amity Affliction'), 'AA');
    expect(AlbumCover.initials('Korn'), 'K');
    expect(AlbumCover.initials('a day to remember'), 'AR');
    expect(AlbumCover.initials('War Of Ages'), 'WA');
    expect(AlbumCover.initials('BABYMETAL'), 'B');
    expect(AlbumCover.initials('  '), '?');
  });

  testWidgets('albums without art show an initials tile', (tester) async {
    await pumpApp(tester, [('Ire', 'Parkway Drive', 2015, 6.5)]);
    expect(find.byKey(const ValueKey('cover-placeholder')), findsOneWidget);
    expect(find.text('PD'), findsOneWidget);
  });

  testWidgets('rankings share card lists the top groups and can switch counts', (tester) async {
    await pumpApp(tester, [
      for (var i = 0; i < 8; i++) ('Album $i', 'Band $i', 2000 + i, 3 + i / 2),
    ]);
    await tester.tap(find.text('Rankings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-rankings')));
    await tester.pumpAndSettle();
    expect(find.text('My top 8 artists'), findsOneWidget);
    expect(find.text('Band 7'), findsOneWidget, reason: 'best artist is listed');
    await tester.tap(find.text('Top 5'));
    await tester.pumpAndSettle();
    expect(find.text('My top 5 artists'), findsOneWidget);
    expect(find.text('Band 0'), findsNothing, reason: 'worst artist is cut from a top 5');
    expect(find.byKey(const ValueKey('share-image')), findsOneWidget);
  });

  testWidgets('group detail shares that group\'s albums', (tester) async {
    await pumpApp(tester, [('Ire', 'Parkway Drive', 2015, 6.5), ('Horizons', 'Parkway Drive', 2007, 8.5)]);
    await tester.tap(find.text('Rankings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parkway Drive'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-group')));
    await tester.pumpAndSettle();
    expect(find.text('My top 2 Parkway Drive albums'), findsOneWidget);
    expect(find.text('Horizons'), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
  });
}
