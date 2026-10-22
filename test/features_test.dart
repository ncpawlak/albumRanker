import 'dart:convert';

import 'package:albumrank/data/album_repository.dart';
import 'package:albumrank/logic/ranking.dart';
import 'package:albumrank/logic/stats.dart';
import 'package:albumrank/services/auto_backup_service.dart';
import 'package:albumrank/theme/rating_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ranking_test.dart' show album;

class _FakeWriter implements BackupWriter {
  final files = <String>[];
  String? lastContents;

  @override
  Future<String> write({required String fileName, required String contents, required String prefix, required int keep}) async {
    files.add(fileName);
    lastContents = contents;
    return 'Downloads/AlbumRank/$fileName';
  }
}

void main() {
  group('rankAlbums', () {
    test('sorts by rating with shared ranks for ties', () {
      final ranked = rankAlbums([
        album('A', 'X', 2000, 'Rock', 7),
        album('B', 'Y', 2001, 'Pop', 10),
        album('C', 'Z', 2002, 'Rap', 7),
        album('D', 'W', 2003, 'Jazz', 3),
      ]);
      expect(ranked.map((r) => r.album.title).toList(), ['B', 'A', 'C', 'D']);
      expect(ranked.map((r) => r.rank).toList(), [1, 2, 2, 4]);
    });
  });

  group('LibraryStats', () {
    test('empty library', () {
      final s = LibraryStats.from(const []);
      expect(s.total, 0);
      expect(s.average, isNull);
      expect(s.distribution, List.filled(19, 0));
    });

    test('counts, distribution and top lists', () {
      final s = LibraryStats.from([
        album('A', 'Radiohead', 1997, 'Rock', 10),
        album('B', 'Radiohead', 2000, 'Rock', 9),
        album('C', 'Frank Ocean', 2016, 'R&B', 9),
        album('D', 'Kendrick', 2015, 'Rap', 6),
      ], top: 2);
      expect(s.total, 4);
      expect(s.average, 9); // 34/4 = 8.5 -> 9
      expect(s.distribution[16], 2); // 9 stars
      expect(s.distribution[18], 1); // 10 stars
      expect(s.artistCount, 3);
      expect(s.genreCount, 3);
      expect(s.topArtists.first.label, 'Radiohead');
      expect(s.topArtists.first.count, 2);
      expect(s.topArtists.length, 2);
      expect(s.topGenres.first.label, 'Rock');
    });
  });

  test('qualityColorRating clamps into the 1-10 scale', () {
    expect(qualityColorRating(2), 1);
    expect(qualityColorRating(12), 10);
    expect(qualityColorRating(6), inInclusiveRange(4, 7));
  });

  group('backups', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('exports are tagged AlbumRank and other apps are rejected', () async {
      final repo = AlbumRepository(prefs);
      await repo.add(title: 'Blonde', artist: 'Frank Ocean', year: 2016, genre: 'R&B', rating: 9);
      final data = jsonDecode(repo.exportJson()) as Map<String, dynamic>;
      expect(data['app'], 'AlbumRank');

      data['app'] = 'GameRank';
      await expectLater(repo.importJson(jsonEncode(data)), throwsFormatException);
      expect(repo.albums.length, 1);
    });

    test('auto-backup runs weekly and skips empty libraries', () async {
      final repo = AlbumRepository(prefs);
      final writer = _FakeWriter();
      var now = DateTime(2025, 1, 1, 9);
      final backup = AutoBackupService(prefs, repo, writer, clock: () => now);

      await backup.runIfDue();
      expect(writer.files, isEmpty, reason: 'nothing to back up yet');

      await repo.add(title: 'Blonde', artist: 'Frank Ocean', year: 2016, genre: 'R&B', rating: 9);
      await backup.runIfDue();
      expect(writer.files, ['AlbumRank-auto-2025-01-01_090000.json']);
      expect(jsonDecode(writer.lastContents!)['albums'], hasLength(1));
      expect(backup.lastBackup, now);

      now = now.add(const Duration(days: 6));
      await backup.runIfDue();
      expect(writer.files, hasLength(1));

      now = now.add(const Duration(days: 1));
      await backup.runIfDue();
      expect(writer.files, hasLength(2));
    });

    test('unsupported without a writer', () async {
      final backup = AutoBackupService(prefs, AlbumRepository(prefs), null);
      expect(backup.supported, isFalse);
      await backup.runIfDue();
      expect(() => backup.backupNow(), throwsUnsupportedError);
    });
  });
}
