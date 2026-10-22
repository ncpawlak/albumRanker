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
    final distribution = List<int>.filled(LibraryStats.ratingBuckets, 0);
    for (final a in albums) {
      distribution[a.ratingHalves - 2 * Album.minRating]++;
    }
    final sum = ratingSum(albums);

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

  /// Album count per half-star rating; index 0 is 1 star, index 1 is 1.5 ...
  final List<int> distribution;

  /// 1, 1.5, 2 ... 10.
  static const ratingBuckets = 2 * (Album.maxRating - Album.minRating) + 1;

  /// The rating a [distribution] index stands for.
  static double bucketRating(int index) => Album.minRating + index / 2;

  final int artistCount;
  final int genreCount;

  /// Most-collected artists, years and genres (by album count).
  final List<CountEntry> topArtists;
  final List<CountEntry> topYears;
  final List<CountEntry> topGenres;
}
