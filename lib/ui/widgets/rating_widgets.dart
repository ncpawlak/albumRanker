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
          rating.toStringAsFixed(decimals),
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

/// Ten small segments, the first [rating] filled with the rating color.
class StarStrip extends StatelessWidget {
  const StarStrip(this.rating, {super.key});

  final int rating;

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
            decoration: BoxDecoration(
              color: i < rating ? fill : empty,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// Tap-to-set 1–10 star rating input.
class RatingPicker extends StatelessWidget {
  const RatingPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value;
    final color = v == null ? scheme.outline : ratingColor(v);
    return LayoutBuilder(builder: (context, constraints) {
      final starSize = ((constraints.maxWidth - 64) / Album.maxRating).clamp(18.0, 34.0);
      return Row(
        children: [
          for (var i = 1; i <= Album.maxRating; i++)
            Semantics(
              button: true,
              label: '$i star${i == 1 ? '' : 's'}',
              selected: v == i,
              child: InkResponse(
                key: ValueKey('star-$i'),
                onTap: () => onChanged(i),
                radius: starSize * 0.7,
                child: Icon(
                  v != null && i <= v ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: starSize,
                  color: v != null && i <= v ? color : scheme.outline,
                ),
              ),
            ),
          const Spacer(),
          if (v != null) RatingBadge(v, size: 40),
        ],
      );
    });
  }
}
