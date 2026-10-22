class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.genre,
    required this.rating,
    this.artworkUrl,
    this.externalId,
    this.wins = 0,
    this.losses = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int minRating = 1;

  /// Ratings move in half stars: 1, 1.5, 2 ... 10.
  static const double ratingStep = 0.5;
  static const int maxRating = 10;

  final String id;
  final String title;
  final String artist;
  final int year;
  final String genre;
  final double rating;

  /// The rating in half-star units (7.5 -> 15), for exact integer math.
  int get ratingHalves => (rating * 2).round();
  final String? artworkUrl;
  final String? externalId;

  /// Head-to-head record from face-offs.
  final int wins;
  final int losses;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get decade => year ~/ 10 * 10;

  static bool isValidRating(num r) => r >= minRating && r <= maxRating && (r * 2) == (r * 2).roundToDouble();

  /// Case/whitespace-insensitive identity used for duplicate detection.
  String get duplicateKey => makeDuplicateKey(title, artist);

  static String makeDuplicateKey(String title, String artist) {
    String norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return '${norm(title)}\u0000${norm(artist)}';
  }

  Album copyWith({
    String? title,
    String? artist,
    int? year,
    String? genre,
    double? rating,
    String? artworkUrl,
    String? externalId,
    int? wins,
    int? losses,
    DateTime? updatedAt,
  }) {
    return Album(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      rating: rating ?? this.rating,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      externalId: externalId ?? this.externalId,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'year': year,
        'genre': genre,
        // Whole ratings stay ints so older app versions can still read backups.
        'rating': rating == rating.roundToDouble() ? rating.toInt() : rating,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
        if (externalId != null) 'externalId': externalId,
        if (wins > 0) 'wins': wins,
        if (losses > 0) 'losses': losses,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Album.fromJson(Map<String, dynamic> json) {
    final rating = (json['rating'] as num).toDouble();
    if (!isValidRating(rating)) {
      throw FormatException('Rating out of range: $rating');
    }
    return Album(
      id: json['id'] as String,
      title: (json['title'] as String).trim(),
      artist: (json['artist'] as String).trim(),
      year: (json['year'] as num).toInt(),
      genre: (json['genre'] as String).trim(),
      rating: rating,
      artworkUrl: json['artworkUrl'] as String?,
      externalId: json['externalId'] as String?,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// 7 -> '7', 7.5 -> '7.5'.
String formatRating(num rating) =>
    rating == rating.roundToDouble() ? rating.toInt().toString() : rating.toStringAsFixed(1);
