import 'package:flutter/material.dart';

import '../models/album.dart';

/// Rating color scale: 1 = red through orange, yellow, green, teal to 10 = blue.
Color ratingColor(int rating) {
  final r = rating.clamp(Album.minRating, Album.maxRating);
  final hue = (r - 1) * 220 / 9;
  return HSLColor.fromAHSL(1, hue, 0.85, 0.55).toColor();
}

/// Readable text color to draw on top of [ratingColor].
Color onRatingColor(int rating) {
  final r = rating.clamp(Album.minRating, Album.maxRating);
  final hue = (r - 1) * 220 / 9;
  return (hue > 40 && hue < 190) ? const Color(0xFF0B0D12) : Colors.white;
}
