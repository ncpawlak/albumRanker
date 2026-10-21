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
    required this.albums,
  });

  final String key;
  final String label;
  final int rank;

  /// Whole-number average rating (rounded half up).
  final int average;

  /// Albums in this group, highest rated first.
  final List<Album> albums;

  int get count => albums.length;
}

/// Rounds sum/count to the nearest whole number, halves rounding up.
/// Uses integer math so 7.5 always becomes 8 (no floating point drift).
int roundedAverage(int sum, int count) {
  if (count <= 0) throw ArgumentError.value(count, 'count', 'must be > 0');
  return (2 * sum + count) ~/ (2 * count);
}

int compareAlbumsByRating(Album a, Album b) {
  final byRating = b.rating.compareTo(a.rating);
  if (byRating != 0) return byRating;
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (byTitle != 0) return byTitle;
  return a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
}

/// Groups [albums] by [by] and ranks groups by their rounded average rating.
///
/// Groups whose rounded averages are equal share a rank (competition ranking:
/// 1, 2, 2, 4). Within a tie, groups with more albums are listed first, then
/// alphabetically by label. Groups with fewer than [minAlbums] albums are
/// excluded before ranking.
List<RankedGroup> rankGroups(List<Album> albums, GroupBy by, {int minAlbums = 1}) {
  final buckets = <String, List<Album>>{};
  final labels = <String, String>{};
  for (final album in albums) {
    final (key, label) = _keyFor(album, by);
    buckets.putIfAbsent(key, () => []).add(album);
    labels.putIfAbsent(key, () => label);
  }

  final unranked = <({String key, String label, int average, List<Album> albums})>[];
  buckets.forEach((key, list) {
    if (list.length < minAlbums) return;
    final sum = list.fold<int>(0, (s, a) => s + a.rating);
    list.sort(compareAlbumsByRating);
    unranked.add((key: key, label: labels[key]!, average: roundedAverage(sum, list.length), albums: list));
  });

  unranked.sort((a, b) {
    final byAvg = b.average.compareTo(a.average);
    if (byAvg != 0) return byAvg;
    final byCount = b.albums.length.compareTo(a.albums.length);
    if (byCount != 0) return byCount;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });

  final result = <RankedGroup>[];
  for (var i = 0; i < unranked.length; i++) {
    final g = unranked[i];
    final rank = (i > 0 && unranked[i - 1].average == g.average) ? result[i - 1].rank : i + 1;
    result.add(RankedGroup(key: g.key, label: g.label, rank: rank, average: g.average, albums: g.albums));
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
