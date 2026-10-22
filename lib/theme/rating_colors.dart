import 'package:flutter/material.dart';

import '../models/album.dart';

/// Rating color scale: 1 = red through orange, yellow, green, teal to 10 = blue.
/// Accepts fractional ratings (e.g. quality scores) for in-between hues.
Color ratingColor(num rating) => HSLColor.fromAHSL(1, _hue(rating), 0.85, 0.55).toColor();

/// Readable text color to draw on top of [ratingColor].
Color onRatingColor(num rating) {
  final hue = _hue(rating);
  return (hue > 40 && hue < 190) ? const Color(0xFF0B0D12) : Colors.white;
}

double _hue(num rating) {
  final r = rating.clamp(Album.minRating, Album.maxRating);
  return (r - 1) * 220 / 9;
}
