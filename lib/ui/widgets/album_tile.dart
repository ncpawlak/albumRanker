import 'package:flutter/material.dart';

import '../../models/album.dart';
import '../../theme/rating_colors.dart';
import 'rating_widgets.dart';

class AlbumTile extends StatelessWidget {
  const AlbumTile({super.key, required this.album, this.onTap, this.leading});

  final Album album;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: ratingColor(album.rating),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${album.artist}  ·  ${album.year}  ·  ${album.genre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    StarStrip(album.rating),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Center(child: RatingBadge(album.rating)),
            ],
          ),
        ),
      ),
    );
  }
}
