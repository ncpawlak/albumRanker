import '../models/album.dart';
import 'ranking.dart';

/// One year on the ratings-by-year chart. Years with no albums are kept so the
/// timeline stays continuous; they have no dots and break the average line.
class YearPoint {
  YearPoint(this.year, this.albums)
      : average = albums.isEmpty ? null : roundedAverage(_sum(albums), albums.length),
        qualityTenths = albums.isEmpty ? null : qualityTenthsFor(_sum(albums), albums.length),
        stacks = _stacks(albums);

  final int year;
  final List<Album> albums;

  /// Whole-number average, or null for an empty year.
  final int? average;

  /// Quality-coefficient score in tenths, or null for an empty year.
  final int? qualityTenths;

  /// How many albums share each rating this year (rating -> count).
  final Map<int, int> stacks;

  bool get isEmpty => albums.isEmpty;
  double? get quality => qualityTenths == null ? null : qualityTenths! / 10;

  static int _sum(List<Album> albums) => albums.fold(0, (s, a) => s + a.rating);

  static Map<int, int> _stacks(List<Album> albums) {
    final m = <int, int>{};
    for (final a in albums) {
      m[a.rating] = (m[a.rating] ?? 0) + 1;
    }
    return m;
  }
}

/// Every year from the earliest to the latest album year, inclusive.
List<YearPoint> yearTimeline(List<Album> albums) {
  if (albums.isEmpty) return const [];
  final byYear = <int, List<Album>>{};
  var minYear = albums.first.year, maxYear = albums.first.year;
  for (final a in albums) {
    byYear.putIfAbsent(a.year, () => []).add(a);
    if (a.year < minYear) minYear = a.year;
    if (a.year > maxYear) maxYear = a.year;
  }
  return [for (var y = minYear; y <= maxYear; y++) YearPoint(y, byYear[y] ?? const [])];
}

/// Picks which year indexes get an x-axis label in the condensed view: the
/// first and last year always, then decade starts that don't crowd them.
/// [minGapSlots] is the minimum distance, in years, between two labels.
List<int> condensedLabelIndexes(List<int> years, double minGapSlots) {
  if (years.isEmpty) return const [];
  final picked = <int>[0];
  final last = years.length - 1;
  for (var i = 1; i < last; i++) {
    if (years[i] % 10 != 0) continue;
    if (i - picked.last < minGapSlots || last - i < minGapSlots) continue;
    picked.add(i);
  }
  if (last > 0) picked.add(last);
  return picked;
}
