import 'dart:convert';

import 'package:albumrank/data/album_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<AlbumRepository> seeded() async {
    final repo = AlbumRepository(prefs);
    await repo.add(title: 'OK Computer', artist: 'Radiohead', year: 1997, genre: 'Alt Rock', rating: 10);
    await repo.add(title: 'Blonde', artist: 'Frank Ocean', year: 2016, genre: 'R&B', rating: 9);
    return repo;
  }

  test('persists albums across instances', () async {
    await seeded();
    final reloaded = AlbumRepository(prefs);
    expect(reloaded.albums.map((a) => a.title), containsAll(['OK Computer', 'Blonde']));
  });

  test('blocks duplicates by normalized title + artist', () async {
    final repo = await seeded();
    expect(
      () => repo.add(title: '  ok   computer ', artist: 'RADIOHEAD', year: 1997, genre: 'Rock', rating: 5),
      throwsA(isA<DuplicateAlbumException>()),
    );
  });

  test('update blocks renaming onto another album but allows self', () async {
    final repo = await seeded();
    final blonde = repo.albums.firstWhere((a) => a.title == 'Blonde');
    await repo.update(blonde.copyWith(rating: 10));
    expect(repo.byId(blonde.id)!.rating, 10);
    expect(
      () => repo.update(blonde.copyWith(title: 'OK Computer', artist: 'Radiohead')),
      throwsA(isA<DuplicateAlbumException>()),
    );
  });

  test('delete and restore (undo)', () async {
    final repo = await seeded();
    final album = repo.albums.first;
    await repo.delete(album.id);
    expect(repo.albums.length, 1);
    await repo.restore(album);
    expect(repo.albums.length, 2);
    expect(AlbumRepository(prefs).albums.length, 2);
  });

  test('genres are distinct and sorted', () async {
    final repo = await seeded();
    await repo.add(title: 'Kid A', artist: 'Radiohead', year: 2000, genre: 'alt rock', rating: 9);
    expect(repo.genres, ['Alt Rock', 'R&B']);
  });

  test('export then import round-trips and replaces library', () async {
    final repo = await seeded();
    final backup = repo.exportJson();
    expect(jsonDecode(backup)['schemaVersion'], AlbumRepository.schemaVersion);

    await repo.add(title: 'Extra', artist: 'Someone', year: 2020, genre: 'Pop', rating: 3);
    final count = await repo.importJson(backup);
    expect(count, 2);
    expect(repo.albums.map((a) => a.title), isNot(contains('Extra')));
  });

  test('import rejects invalid files without touching data', () async {
    final repo = await seeded();
    await expectLater(repo.importJson('{"foo": 1}'), throwsFormatException);
    await expectLater(
      repo.importJson(jsonEncode({
        'schemaVersion': 1,
        'albums': [
          {'id': 'x', 'title': 'Bad', 'artist': 'A', 'year': 2000, 'genre': 'G', 'rating': 11,
            'createdAt': '2024-01-01T00:00:00.000', 'updatedAt': '2024-01-01T00:00:00.000'},
        ],
      })),
      throwsFormatException,
    );
    await expectLater(repo.importJson('{"schemaVersion": 99, "albums": []}'), throwsFormatException);
    expect(repo.albums.length, 2);
  });
}
