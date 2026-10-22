import 'dart:math';

import '../models/album.dart';

/// Which pairs of albums may meet in a face-off.
enum FaceOffMatch {
  tied('Tied', 'Only albums with the exact same rating'),
  close('Within ½', 'Ratings no more than half a star apart'),
  any('Any', 'Any two albums in the selection');

  const FaceOffMatch(this.label, this.description);
  final String label;
  final String description;

  bool allows(Album a, Album b) => switch (this) {
        FaceOffMatch.tied => a.ratingHalves == b.ratingHalves,
        FaceOffMatch.close => (a.ratingHalves - b.ratingHalves).abs() <= 1,
        FaceOffMatch.any => true,
      };
}

/// Optional narrowing of the pool to one artist, genre or year.
enum FaceOffScope {
  all('All'),
  artist('Artist'),
  genre('Genre'),
  year('Year');

  const FaceOffScope(this.label);
  final String label;

  String? valueOf(Album a) => switch (this) {
        FaceOffScope.all => null,
        FaceOffScope.artist => a.artist,
        FaceOffScope.genre => a.genre,
        FaceOffScope.year => '${a.year}',
      };

  /// Distinct values in [albums], sorted (years newest first).
  List<String> valuesIn(Iterable<Album> albums) {
    final values = {for (final a in albums) valueOf(a)!}.toList();
    if (this == FaceOffScope.year) {
      values.sort((a, b) => b.compareTo(a));
    } else {
      values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return values;
  }
}

/// Albums matching the scope (case-insensitive) and, when non-empty, the chosen ratings.
List<Album> faceOffPool(
  Iterable<Album> albums, {
  FaceOffScope scope = FaceOffScope.all,
  String? scopeValue,
  Set<double> ratings = const {},
}) {
  final want = scopeValue?.trim().toLowerCase();
  return [
    for (final a in albums)
      if ((scope == FaceOffScope.all || want == null || scope.valueOf(a)!.trim().toLowerCase() == want) &&
          (ratings.isEmpty || ratings.contains(a.rating)))
        a,
  ];
}

/// Number of distinct match-ups [match] allows within [pool].
int countMatchUps(List<Album> pool, FaceOffMatch match) {
  var n = 0;
  for (var i = 0; i < pool.length; i++) {
    for (var j = i + 1; j < pool.length; j++) {
      if (match.allows(pool[i], pool[j])) n++;
    }
  }
  return n;
}

/// A rating change offered after a pick; [changes] maps album id to new rating.
class FaceOffOption {
  const FaceOffOption(this.label, this.changes);

  final String label;
  final Map<String, double> changes;
}

/// Changes to offer once [winner] beats [loser]. Empty when the ratings already
/// agree (the winner is rated higher). The caller adds a "keep" choice.
List<FaceOffOption> faceOffOptions(Album winner, Album loser) {
  const step = Album.ratingStep;
  if (winner.ratingHalves > loser.ratingHalves) return const [];
  final up = winner.rating + step, down = loser.rating - step;
  final canRaise = up <= Album.maxRating, canLower = down >= Album.minRating;
  final upset = winner.ratingHalves < loser.ratingHalves;
  return [
    if (canRaise) FaceOffOption('Raise ${winner.title} to ${formatRating(up)}', {winner.id: up}),
    if (canLower) FaceOffOption('Lower ${loser.title} to ${formatRating(down)}', {loser.id: down}),
    if (upset && canRaise && canLower)
      FaceOffOption('Both: ${formatRating(up)} and ${formatRating(down)}', {winner.id: up, loser.id: down}),
  ];
}

/// One match-up as played, with the ratings each album had going in.
class FaceOffResult {
  const FaceOffResult({required this.left, required this.right, required this.winnerId, this.changes = const {}});

  final Album left;
  final Album right;

  /// Null when it was called too close.
  final String? winnerId;

  /// Ratings changed because of this match-up (album id → new rating).
  final Map<String, double> changes;

  FaceOffResult withChanges(Map<String, double> c) =>
      FaceOffResult(left: left, right: right, winnerId: winnerId, changes: c);
}

/// One run of face-offs. Ratings can change between rounds, so each call to
/// [next] takes the current albums; pairs are never repeated and albums that
/// have appeared least are favored.
class FaceOffSession {
  FaceOffSession(Iterable<Album> pool, this.match, {this.rounds, Random? random})
      : _ids = {for (final a in pool) a.id},
        _random = random ?? Random();

  final Set<String> _ids;
  final FaceOffMatch match;

  /// Session length; null means keep going until stopped or out of pairs.
  final int? rounds;
  final Random _random;
  final _played = <String>{};
  final _appearances = <String, int>{};
  final results = <FaceOffResult>[];

  int get round => results.length + 1;
  bool get roundsDone => rounds != null && results.length >= rounds!;

  static String _pairKey(Album a, Album b) => a.id.compareTo(b.id) < 0 ? '${a.id}|${b.id}' : '${b.id}|${a.id}';

  /// The next pair as (left, right) from [current] library albums, or null when
  /// the round limit is reached or no unplayed pair is allowed.
  (Album, Album)? next(Iterable<Album> current) {
    if (roundsDone) return null;
    final pool = [for (final a in current) if (_ids.contains(a.id)) a];
    var best = <(Album, Album)>[];
    var bestScore = 1 << 30;
    for (var i = 0; i < pool.length; i++) {
      for (var j = i + 1; j < pool.length; j++) {
        final a = pool[i], b = pool[j];
        if (!match.allows(a, b) || _played.contains(_pairKey(a, b))) continue;
        final score = (_appearances[a.id] ?? 0) + (_appearances[b.id] ?? 0);
        if (score < bestScore) {
          bestScore = score;
          best = [(a, b)];
        } else if (score == bestScore) {
          best.add((a, b));
        }
      }
    }
    if (best.isEmpty) return null;
    final (a, b) = best[_random.nextInt(best.length)];
    return _random.nextBool() ? (a, b) : (b, a);
  }

  /// Records the pick; returns the index of the result so changes can be attached.
  int record(Album left, Album right, String? winnerId) {
    _played.add(_pairKey(left, right));
    for (final a in [left, right]) {
      _appearances[a.id] = (_appearances[a.id] ?? 0) + 1;
    }
    results.add(FaceOffResult(left: left, right: right, winnerId: winnerId));
    return results.length - 1;
  }

  void attachChanges(int index, Map<String, double> changes) {
    results[index] = results[index].withChanges(changes);
  }
}
