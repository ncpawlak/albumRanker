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

/// Rating input sized for thumbs: a big colored score with −/+ buttons for
/// half-star nudges, and a slider (1–10 in half steps) for quick changes.
class RatingPicker extends StatelessWidget {
  const RatingPicker({super.key, required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double> onChanged;

  static const _start = 5.5;

  void _step(int dir) {
    final next = ((value ?? _start) + dir * Album.ratingStep).clamp(Album.minRating.toDouble(), Album.maxRating.toDouble());
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = value;
    final color = v == null ? scheme.outline : ratingColor(v);
    return Column(
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              key: const ValueKey('rating-minus'),
              tooltip: 'Half a star less',
              iconSize: 28,
              onPressed: v == Album.minRating ? null : () => _step(-1),
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  v == null
                      ? Text('Not rated', key: const ValueKey('rating-value'),
                          style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant))
                      : RatingBadge(v, key: const ValueKey('rating-value'), size: 64),
                  const SizedBox(height: 8),
                  StarStrip(v ?? 0),
                ],
              ),
            ),
            IconButton.filledTonal(
              key: const ValueKey('rating-plus'),
              tooltip: 'Half a star more',
              iconSize: 28,
              onPressed: v == Album.maxRating ? null : () => _step(1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: scheme.surfaceContainerHigh,
            overlayColor: color.withValues(alpha: 0.15),
            valueIndicatorColor: color,
            valueIndicatorTextStyle: TextStyle(color: onRatingColor(v ?? _start), fontWeight: FontWeight.w800),
            showValueIndicator: ShowValueIndicator.onDrag,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
          ),
          child: Slider(
            key: const ValueKey('rating-slider'),
            min: Album.minRating.toDouble(),
            max: Album.maxRating.toDouble(),
            divisions: (Album.maxRating - Album.minRating) * 2,
            value: v ?? _start,
            label: formatRating(v ?? _start),
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final n in [Album.minRating, Album.maxRating])
                Text('$n', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Square cover thumbnail; albums without art (or offline) get a tile in the
/// rating color with the artist's initials.
class AlbumCover extends StatelessWidget {
  const AlbumCover({super.key, required this.album, this.size = 52});

  final Album album;
  final double size;

  static String initials(String artist) {
    final words = artist
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'the')
        .toList();
    if (words.isEmpty) return '?';
    final letters = words.length == 1 ? words.first.characters.first : '${words.first.characters.first}${words.last.characters.first}';
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      key: const ValueKey('cover-placeholder'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ratingColor(album.rating), Color.lerp(ratingColor(album.rating), Colors.black, 0.35)!],
        ),
      ),
      child: Text(
        initials(album.artist),
        style: TextStyle(color: onRatingColor(album.rating), fontWeight: FontWeight.w800, fontSize: size * 0.34),
      ),
    );
    final url = album.artworkUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: url == null
          ? placeholder
          : Image.network(
              size > 80 ? url : url.replaceFirst('600x600bb', '200x200bb'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => placeholder,
              frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : placeholder,
            ),
    );
  }
}
