import 'package:album_ranker/logic/ranking.dart';
import 'package:album_ranker/models/album.dart';
import 'package:flutter_test/flutter_test.dart';

Album album(String title, String artist, int year, String genre, int rating) {
  final t = DateTime(2024);
  return Album(
    id: '$title-$artist',
    title: title,
    artist: artist,
    year: year,
    genre: genre,
    rating: rating,
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  group('roundedAverage', () {
    test('rounds half up', () {
      expect(roundedAverage(15, 2), 8); // 7.5
      expect(roundedAverage(13, 2), 7); // 6.5 -> 7
      expect(roundedAverage(22, 3), 7); // 7.33
      expect(roundedAverage(23, 3), 8); // 7.67
      expect(roundedAverage(10, 1), 10);
    });

    test('rejects empty groups', () {
      expect(() => roundedAverage(0, 0), throwsArgumentError);
    });
  });

  group('rankGroups', () {
    final albums = [
      album('OK Computer', 'Radiohead', 1997, 'Alt Rock', 10),
      album('Kid A', 'Radiohead', 2000, 'Alt Rock', 9), // Radiohead avg 9.5 -> 10
      album('Blonde', 'Frank Ocean', 2016, 'R&B', 10), // 10
      album('Rumours', 'Fleetwood Mac', 1977, 'Rock', 9), // 9
      album('Currents', 'Tame Impala', 2015, 'Psychedelic', 6),
      album('Lonerism', 'tame impala', 2012, 'Psychedelic', 7), // 6.5 -> 7, case-insensitive artist
    ];

    test('groups by artist with whole-number averages and shared ranks', () {
      final groups = rankGroups(albums, GroupBy.artist);
      expect(groups.map((g) => (g.label, g.average, g.rank)).toList(), [
        ('Radiohead', 10, 1), // tie at 10, more albums listed first
        ('Frank Ocean', 10, 1),
        ('Fleetwood Mac', 9, 3), // competition ranking skips 2
        ('Tame Impala', 7, 4),
      ]);
      expect(groups.first.albums.map((a) => a.title), ['OK Computer', 'Kid A']);
    });

    test('groups by decade and genre', () {
      final decades = rankGroups(albums, GroupBy.decade);
      expect(decades.map((g) => g.label).toSet(), {'1970s', '1990s', '2000s', '2010s'});
      final s2010 = decades.firstWhere((g) => g.label == '2010s');
      expect(s2010.count, 3);
      expect(s2010.average, 8); // (10+6+7)/3 = 7.67

      final genres = rankGroups(albums, GroupBy.genre);
      expect(genres.first.label, 'Alt Rock');
      expect(genres.first.average, 10);
    });

    test('min album filter excludes small groups before ranking', () {
      final groups = rankGroups(albums, GroupBy.artist, minAlbums: 2);
      expect(groups.map((g) => (g.label, g.rank)).toList(), [('Radiohead', 1), ('Tame Impala', 2)]);
    });

    test('ties with equal counts sort alphabetically', () {
      final groups = rankGroups([
        album('A', 'Zed', 2000, 'Pop', 8),
        album('B', 'Abe', 2000, 'Pop', 8),
      ], GroupBy.artist);
      expect(groups.map((g) => (g.label, g.rank)).toList(), [('Abe', 1), ('Zed', 1)]);
    });
  });

  group('quality coefficient', () {
    test('scores (sum + 10) / (count + 2) in tenths', () {
      expect(qualityTenthsFor(8, 1), 60); // 18/3
      expect(qualityTenthsFor(28, 4), 63); // 38/6 = 6.33
      expect(qualityTenthsFor(10, 1), 67); // 20/3 = 6.67
      expect(qualityTenthsFor(120, 20), 59); // twenty 6s = 5.91
    });

    List<Album> many(int year, int rating, int n) =>
        [for (var i = 0; i < n; i++) album('$year-$i', 'A$i', year, 'Rock', rating)];

    test('four 7s outrank one 8 when on, not when off', () {
      final albums = [...many(2016, 8, 1), ...many(2017, 7, 4)];
      final off = rankGroups(albums, GroupBy.year);
      expect(off.map((g) => g.label), ['2016', '2017']);
      final on = rankGroups(albums, GroupBy.year, useQuality: true);
      expect(on.map((g) => g.label), ['2017', '2016']);
      expect(on.first.quality, 6.3);
      expect(on.map((g) => g.rank), [1, 2]);
    });

    test('a pile of mediocre albums does not beat a few great ones', () {
      final albums = [...many(2001, 8, 3), ...many(2002, 6, 20)];
      final on = rankGroups(albums, GroupBy.year, useQuality: true);
      expect(on.first.label, '2001');
    });

    test('equal one-decimal scores share a rank, more albums first', () {
      // three 9s (7.4) vs eight 8s (7.4)
      final albums = [...many(2010, 9, 3), ...many(2011, 8, 8)];
      final on = rankGroups(albums, GroupBy.year, useQuality: true);
      expect(on.map((g) => g.label), ['2011', '2010']);
      expect(on.map((g) => g.rank), [1, 1]);
    });
  });
}