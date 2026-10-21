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
}
