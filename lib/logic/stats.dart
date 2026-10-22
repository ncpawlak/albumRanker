import '../models/album.dart';
import 'ranking.dart';

class CountEntry {
  const CountEntry(this.label, this.count, this.average);

  final String label;
  final int count;

  /// Whole-number average rating of the albums counted.
  final int average;
}

class LibraryStats {
  LibraryStats._({
    required this.total,
    required this.average,
    required this.distribution,
    required this.artistCount,
    required this.genreCount,
    required this.topArtists,
    required this.topYears,
    required this.topGenres,
  });

  factory LibraryStats.from(List<Album> albums, {int top = 5}) {
    final distribution = List<int>.filled(Album.maxRating, 0);
    var sum = 0;
    for (final a in albums) {
      distribution[a.rating - 1]++;
      sum += a.rating;
    }

    List<CountEntry> byCount(GroupBy by) {
      final groups = rankGroups(albums, by)
        ..sort((a, b) {
          final c = b.count.compareTo(a.count);
          if (c != 0) return c;
          final avg = b.average.compareTo(a.average);
          if (avg != 0) return avg;
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
      return [for (final g in groups) CountEntry(g.label, g.count, g.average)];
    }

    final artists = byCount(GroupBy.artist);
    final genres = byCount(GroupBy.genre);
    return LibraryStats._(
      total: albums.length,
      average: albums.isEmpty ? null : roundedAverage(sum, albums.length),
      distribution: distribution,
      artistCount: artists.length,
      genreCount: genres.length,
      topArtists: artists.take(top).toList(),
      topYears: byCount(GroupBy.year).take(top).toList(),
      topGenres: genres.take(top).toList(),
    );
  }

  final int total;

  /// Whole-number average of every rating, or null when the library is empty.
  final int? average;

  /// Album count per rating; index 0 is 1 star.
  final List<int> distribution;

  final int artistCount;
  final int genreCount;

  /// Most-collected artists, years and genres (by album count).
  final List<CountEntry> topArtists;
  final List<CountEntry> topYears;
  final List<CountEntry> topGenres;
}
