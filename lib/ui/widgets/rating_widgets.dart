import 'package:flutter/material.dart';

import '../../models/album.dart';
import '../../theme/rating_colors.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge(this.rating, {super.key, this.size = 32, this.decimals = 0, this.colorRating});

  /// Shows a group's quality score, colored on the stretched quality scale.
  RatingBadge.quality(double quality, {Key? key, double size = 32})
      : this(quality, key: key, size: size, decimals: 1, colorRating: qualityColorRating(quality));

  final num rating;
  final double size;

  /// Digits after the decimal point; quality scores use 1.
  final int decimals;

  /// Value used for the color when it differs from the displayed [rating].
  final num? colorRating;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: size),
      height: size * 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: ratingColor(colorRating ?? rating),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      // widthFactor keeps the badge hugging its text instead of filling loose parents.
      child: Center(
        widthFactor: 1,
        child: Text(
          decimals == 0 ? formatRating(rating) : rating.toStringAsFixed(decimals),
          style: TextStyle(
            color: onRatingColor(colorRating ?? rating),
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}

/// Ten small segments filled up to [rating]; a half star half-fills its segment.
class StarStrip extends StatelessWidget {
  const StarStrip(this.rating, {super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.surfaceContainerHigh;
    final fill = ratingColor(rating);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < Album.maxRating; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 2),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: i + 1 <= rating ? fill : empty,
              borderRadius: BorderRadius.circular(2),
            ),
            child: i < rating && rating < i + 1
                ? Align(alignment: Alignment.centerLeft, child: Container(width: 4.5, color: fill))
                : null,
          ),
      ],
    );
  }
}

/// Tap-to-set rating input: tap a star for a whole rating, or its left half
/// for a half star (e.g. the left half of star 8 gives 7.5).
class RatingPicker extends StatelessWidget {
  const RatingPicker({super.key, required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value;
    final color = v == null ? scheme.outline : ratingColor(v);
    return LayoutBuilder(builder: (context, constraints) {
      final starSize = ((constraints.maxWidth - 80) / Album.maxRating).clamp(18.0, 34.0);
      return Row(
        children: [
          for (var i = 1; i <= Album.maxRating; i++)
            Semantics(
              button: true,
              label: '$i star${i == 1 ? '' : 's'}',
              selected: v == i,
              child: GestureDetector(
                key: ValueKey('star-$i'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final half = d.localPosition.dx < starSize / 2 && i > Album.minRating;
                  onChanged(half ? i - 0.5 : i.toDouble());
                },
                child: Icon(
                  v == null || v <= i - 1
                      ? Icons.star_outline_rounded
                      : v < i
                          ? Icons.star_half_rounded
                          : Icons.star_rounded,
                  size: starSize,
                  color: v != null && v > i - 1 ? color : scheme.outline,
                ),
              ),
            ),
          const Spacer(),
          if (v != null) RatingBadge(v, key: const ValueKey('rating-value'), size: 40),
        ],
      );
    });
  }
}