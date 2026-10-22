import '../models/album.dart';

enum GroupBy {
  year('Year'),
  decade('Decade'),
  genre('Genre'),
  artist('Artist');

  const GroupBy(this.label);
  final String label;
}

class RankedGroup {
  const RankedGroup({
    required this.key,
    required this.label,
    required this.rank,
    required this.average,
    required this.qualityTenths,
    required this.albums,
  });

  final String key;
  final String label;
  final int rank;

  /// Whole-number average rating (rounded half up).
  final int average;

  /// Quality score in tenths (63 = 6.3); see [qualityTenthsFor].
  final int qualityTenths;

  /// Albums in this group, highest rated first.
  final List<Album> albums;

  int get count => albums.length;
  double get quality => qualityTenths / 10;
}

/// Neutral rating that small groups are pulled toward by the quality coefficient.
const qualityPrior = 5;

/// How many phantom [qualityPrior]-star albums every group is padded with.
/// 2 was the midpoint of the strengths (1.5–3) that ranked a set of test
/// scenarios fairly, e.g. four 7s (6.3) beat one 8 (6.0), while twenty 6s
/// (5.9) still lose to three 8s (6.8).
const qualityWeight = 2;

/// Quality coefficient: (sum + prior * weight) / (count + weight), returned in
/// tenths and rounded half up with integer math. [sum] may contain half stars.
int qualityTenthsFor(num sum, int count) {
  if (count <= 0) throw ArgumentError.value(count, 'count', 'must be > 0');
  final halves = _halves(sum);
  final numerator = 10 * (halves + 2 * qualityPrior * qualityWeight);
  final den = 2 * (count + qualityWeight);
  return (2 * numerator + den) ~/ (2 * den);
}

/// Rounds sum/count to the nearest whole number, halves rounding up.
/// Uses integer half-star math so 7.5 always becomes 8 (no floating point drift).
int roundedAverage(num sum, int count) {
  if (count <= 0) throw ArgumentError.value(count, 'count', 'must be > 0');
  return (_halves(sum) + count) ~/ (2 * count);
}

int _halves(num sum) => (sum * 2).round();

/// Sum of [albums]' ratings (may include half stars).
double ratingSum(Iterable<Album> albums) => albums.fold(0.0, (s, a) => s + a.ratingHalves) / 2;

int compareAlbumsByRating(Album a, Album b) {
  final byRating = b.rating.compareTo(a.rating);
  if (byRating != 0) return byRating;
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (byTitle != 0) return byTitle;
  return a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
}

/// How albums inside a group are listed.
enum AlbumSort {
  rating('Rating'),
  title('A–Z'),
  year('Year');

  const AlbumSort(this.label);
  final String label;

  static AlbumSort fromName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => AlbumSort.rating);
}

/// Rating high→low, title A→Z, or year newest first; ties fall back to rating
/// then title so the order is always stable.
List<Album> sortAlbums(List<Album> albums, AlbumSort sort) {
  int byTitle(Album a, Album b) {
    final t = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    return t != 0 ? t : a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
  }

  final sorted = [...albums];
  switch (sort) {
    case AlbumSort.rating:
      sorted.sort(compareAlbumsByRating);
    case AlbumSort.title:
      sorted.sort((a, b) {
        final t = byTitle(a, b);
        return t != 0 ? t : b.rating.compareTo(a.rating);
      });
    case AlbumSort.year:
      sorted.sort((a, b) {
        final y = b.year.compareTo(a.year);
        return y != 0 ? y : compareAlbumsByRating(a, b);
      });
  }
  return sorted;
}

/// Groups [albums] by [by] and ranks groups by their rounded average rating.
///
/// Groups whose rounded averages are equal share a rank (competition ranking:
/// 1, 2, 2, 4). Within a tie, groups with more albums are listed first, then
/// alphabetically by label. Groups with fewer than [minAlbums] albums are
/// excluded before ranking.
///
/// With [useQuality], groups are ranked by their one-decimal quality score
/// instead; the same tie rules apply to equal scores.
List<RankedGroup> rankGroups(List<Album> albums, GroupBy by, {int minAlbums = 1, bool useQuality = false}) {
  final buckets = <String, List<Album>>{};
  final labels = <String, String>{};
  for (final album in albums) {
    final (key, label) = _keyFor(album, by);
    buckets.putIfAbsent(key, () => []).add(album);
    labels.putIfAbsent(key, () => label);
  }

  final unranked = <({String key, String label, int average, int quality, List<Album> albums})>[];
  buckets.forEach((key, list) {
    if (list.length < minAlbums) return;
    final sum = ratingSum(list);
    list.sort(compareAlbumsByRating);
    unranked.add((
      key: key,
      label: labels[key]!,
      average: roundedAverage(sum, list.length),
      quality: qualityTenthsFor(sum, list.length),
      albums: list,
    ));
  });

  int score(({String key, String label, int average, int quality, List<Album> albums}) g) =>
      useQuality ? g.quality : g.average;

  unranked.sort((a, b) {
    final byAvg = score(b).compareTo(score(a));
    if (byAvg != 0) return byAvg;
    final byCount = b.albums.length.compareTo(a.albums.length);
    if (byCount != 0) return byCount;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });

  final result = <RankedGroup>[];
  for (var i = 0; i < unranked.length; i++) {
    final g = unranked[i];
    final rank = (i > 0 && score(unranked[i - 1]) == score(g)) ? result[i - 1].rank : i + 1;
    result.add(RankedGroup(
      key: g.key,
      label: g.label,
      rank: rank,
      average: g.average,
      qualityTenths: g.quality,
      albums: g.albums,
    ));
  }
  return result;
}

/// Every album ranked by its own rating, with ties sharing a rank (1, 2, 2, 4).
List<({int rank, Album album})> rankAlbums(List<Album> albums) {
  final sorted = [...albums]..sort(compareAlbumsByRating);
  final result = <({int rank, Album album})>[];
  for (var i = 0; i < sorted.length; i++) {
    final tied = i > 0 && sorted[i - 1].rating == sorted[i].rating;
    result.add((rank: tied ? result[i - 1].rank : i + 1, album: sorted[i]));
  }
  return result;
}

(String, String) _keyFor(Album album, GroupBy by) {
  switch (by) {
    case GroupBy.year:
      return ('${album.year}', '${album.year}');
    case GroupBy.decade:
      return ('${album.decade}', '${album.decade}s');
    case GroupBy.genre:
      return (album.genre.trim().toLowerCase(), album.genre.trim());
    case GroupBy.artist:
      return (album.artist.trim().toLowerCase(), album.artist.trim());
  }
}
