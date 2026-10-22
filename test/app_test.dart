import 'package:albumrank/data/album_repository.dart';
import 'package:albumrank/data/settings_controller.dart';
import 'package:albumrank/main.dart';
import 'package:albumrank/services/album_lookup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlbumRepository repo;

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = AlbumRepository(prefs);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(AlbumRankerApp(
      repository: repo,
      settings: SettingsController(prefs),
      lookup: AlbumLookupService(client: MockClient((_) async => http.Response('{"results":[]}', 200))),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> addAlbum(WidgetTester tester, String title, String artist, String year, String genre, int stars) async {
    await tester.tap(find.byKey(const ValueKey('add-album')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-title')), title);
    await tester.enterText(find.byKey(const ValueKey('field-artist')), artist);
    await tester.enterText(find.byKey(const ValueKey('field-year')), year);
    await tester.enterText(find.byKey(const ValueKey('field-genre')), genre);
    await tester.tap(find.byKey(ValueKey('star-$stars')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('save-album')));
    await tester.pumpAndSettle();
  }

  testWidgets('add albums, see them listed, and view rankings', (tester) async {
    await pumpApp(tester);
    expect(find.text('No albums yet'), findsOneWidget);

    await addAlbum(tester, 'OK Computer', 'Radiohead', '1997', 'Alt Rock', 10);
    await addAlbum(tester, 'Kid A', 'Radiohead', '2000', 'Alt Rock', 9);
    await addAlbum(tester, 'Rumours', 'Fleetwood Mac', '1977', 'Rock', 8);

    expect(repo.albums, hasLength(3));
    expect(find.text('OK Computer'), findsOneWidget);
    expect(find.text('3 albums'), findsOneWidget);

    await tester.tap(find.text('Rankings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('crown-1')), findsOneWidget);
    expect(find.text('Radiohead'), findsOneWidget);
    expect(find.text('2 albums'), findsOneWidget);
  });

  testWidgets('validation requires every field', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('add-album')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-album')));
    await tester.pumpAndSettle();
    expect(find.text('Album name is required'), findsOneWidget);
    expect(find.text('Artist is required'), findsOneWidget);
    expect(find.text('Year is required'), findsOneWidget);
    expect(find.text('Genre is required'), findsOneWidget);
    expect(find.text('Rating is required'), findsOneWidget);
    expect(repo.albums, isEmpty);
  });

  testWidgets('duplicate album offers to edit existing', (tester) async {
    await pumpApp(tester);
    await addAlbum(tester, 'Blonde', 'Frank Ocean', '2016', 'R&B', 9);
    await addAlbum(tester, 'blonde', 'frank ocean', '2016', 'R&B', 5);
    expect(find.text('Already in your list'), findsOneWidget);
    await tester.tap(find.text('Edit existing'));
    await tester.pumpAndSettle();
    expect(find.text('Edit album'), findsOneWidget);
    expect(repo.albums, hasLength(1));
    expect(repo.albums.single.rating, 9);
  });
}
