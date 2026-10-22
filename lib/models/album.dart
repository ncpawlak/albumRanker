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
    required this.createdAt,
    required this.updatedAt,
  });

  static const int minRating = 1;
  static const int maxRating = 10;

  final String id;
  final String title;
  final String artist;
  final int year;
  final String genre;
  final int rating;
  final String? artworkUrl;
  final String? externalId;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get decade => year ~/ 10 * 10;

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
    int? rating,
    String? artworkUrl,
    String? externalId,
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
        'rating': rating,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
        if (externalId != null) 'externalId': externalId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Album.fromJson(Map<String, dynamic> json) {
    final rating = (json['rating'] as num).toInt();
    if (rating < minRating || rating > maxRating) {
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
