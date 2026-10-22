import 'package:albumrank/data/album_repository.dart';
import 'package:albumrank/data/settings_controller.dart';
import 'package:albumrank/logic/ranking.dart';
import 'package:albumrank/logic/year_chart.dart';
import 'package:albumrank/main.dart';
import 'package:albumrank/services/album_lookup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ranking_test.dart' show album;

void main() {
  group('yearTimeline', () {
    test('spans earliest to latest year and keeps empty years as gaps', () {
      final t = yearTimeline([
        album('A', 'X', 2004, 'Rock', 8),
        album('B', 'X', 2002, 'Rock', 6),
        album('C', 'Y', 2002, 'Rock', 9),
        album('D', 'Y', 2002, 'Rock', 9),
      ]);
      expect(t.map((p) => p.year).toList(), [2002, 2003, 2004]);
      expect(t[1].isEmpty, isTrue);
      expect(t[1].average, isNull);
      expect(t[1].quality, isNull);
      expect(t[0].average, 8); // 24/3
      expect(t[0].stacks, {6: 1, 9: 2});
      expect(t[0].qualityTenths, qualityTenthsFor(24, 3));
      expect(t[2].average, 8);
    });

    test('empty library has no years', () {
      expect(yearTimeline(const []), isEmpty);
    });
  });

  group('condensedLabelIndexes', () {
    test('always labels first and last, plus decade starts with room', () {
      final years = [for (var y = 2001; y <= 2022; y++) y];
      final picked = condensedLabelIndexes(years, 3).map((i) => years[i]).toList();
      expect(picked, [2001, 2010, 2022]); // 2020 is too close to 2022
    });

    test('a single year gets one label', () {
      expect(condensedLabelIndexes([1999], 3), [0]);
    });
  });

  group('sortAlbums', () {
    final albums = [
      album('Blonde', 'Frank Ocean', 2016, 'R&B', 9),
      album('channel ORANGE', 'Frank Ocean', 2012, 'R&B', 10),
      album('Endless', 'Frank Ocean', 2016, 'R&B', 7),
    ];

    test('rating high to low', () {
      expect(sortAlbums(albums, AlbumSort.rating).map((a) => a.title), ['channel ORANGE', 'Blonde', 'Endless']);
    });

    test('alphabetical, case-insensitive', () {
      expect(sortAlbums(albums, AlbumSort.title).map((a) => a.title), ['Blonde', 'channel ORANGE', 'Endless']);
    });

    test('year newest first, ties by rating', () {
      expect(sortAlbums(albums, AlbumSort.year).map((a) => a.title), ['Blonde', 'Endless', 'channel ORANGE']);
    });
  });

  group('settings', () {
    test('group sort and chart mode persist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsController(prefs);
      expect(s.groupSort, AlbumSort.rating);
      expect(s.chartCondensed, isFalse);
      await s.setGroupSort(AlbumSort.year);
      await s.setChartCondensed(true);
      final reloaded = SettingsController(prefs);
      expect(reloaded.groupSort, AlbumSort.year);
      expect(reloaded.chartCondensed, isTrue);
    });
  });

  group('UI', () {
    late AlbumRepository repo;

    Future<void> pumpApp(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = AlbumRepository(prefs);
      await repo.add(title: 'OK Computer', artist: 'Radiohead', year: 1997, genre: 'Rock', rating: 10);
      await repo.add(title: 'Kid A', artist: 'Radiohead', year: 2000, genre: 'Rock', rating: 9);
      await repo.add(title: 'Amnesiac', artist: 'Radiohead', year: 2001, genre: 'Rock', rating: 7);
      await repo.add(title: 'Blonde', artist: 'Frank Ocean', year: 2016, genre: 'R&B', rating: 8);
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await tester.pumpWidget(AlbumRankerApp(
        repository: repo,
        settings: SettingsController(prefs),
        lookup: AlbumLookupService(client: MockClient((_) async => http.Response('{"results":[]}', 200))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('rankings show gold, silver and bronze crowns', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Rankings'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byWidgetPredicate((w) => w is SegmentedButton), matching: find.text('Albums')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('crown-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('crown-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('crown-3')), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
    });

    testWidgets('artist detail sorts by rating, A–Z and year', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Rankings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radiohead'));
      await tester.pumpAndSettle();

      List<double> ys(List<String> titles) => [for (final t in titles) tester.getTopLeft(find.text(t)).dy];
      bool ordered(List<String> titles) {
        final y = ys(titles);
        return y[0] < y[1] && y[1] < y[2];
      }

      expect(ordered(['OK Computer', 'Kid A', 'Amnesiac']), isTrue);
      await tester.tap(find.text('A–Z'));
      await tester.pumpAndSettle();
      expect(ordered(['Amnesiac', 'Kid A', 'OK Computer']), isTrue);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('group-sort')), matching: find.text('Year')));
      await tester.pumpAndSettle();
      expect(ordered(['Amnesiac', 'Kid A', 'OK Computer']), isTrue);
    });

    testWidgets('artist detail has a chart; tapping a dot opens the album', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Rankings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radiohead'));
      await tester.pumpAndSettle();
      final chart = find.byKey(const ValueKey('year-chart'));
      expect(chart, findsOneWidget);
      // Radiohead spans 1997–2001; fit it and tap the 1997 slot at rating 10.
      await tester.tap(find.byKey(const ValueKey('chart-fit')));
      await tester.pumpAndSettle();
      final box = tester.getRect(chart);
      final slot = box.width / 5;
      final y10 = box.top + 12; // top grid line is rating 10
      await tester.tapAt(Offset(box.left + slot / 2, y10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('save-album')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'OK Computer'), findsOneWidget);
    });

    testWidgets('single-album and year groups have no chart', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Rankings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frank Ocean'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('year-chart')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byWidgetPredicate((w) => w is SegmentedButton), matching: find.text('Year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1997'));
      await tester.pumpAndSettle();
      expect(find.text('Rank #1 by year'), findsOneWidget);
      expect(find.byKey(const ValueKey('year-chart')), findsNothing);
    });

    testWidgets('stats chart toggles fit and opens a year on tap', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.text('RATINGS BY YEAR'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chart-fit')));
      await tester.pumpAndSettle();
      // Condensed: 1997..2016 fits; tap the first slot (1997).
      final chart = find.byKey(const ValueKey('year-chart'));
      final box = tester.getRect(chart);
      await tester.tapAt(Offset(box.left + 3, box.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('OK Computer'), findsOneWidget);
      expect(find.text('Rank #1 by year'), findsOneWidget);
    });
  });
}
