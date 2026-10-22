import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../logic/ranking.dart';
import 'album_edit_screen.dart';
import 'widgets/album_tile.dart';
import 'widgets/rating_widgets.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupBy, required this.groupKey});

  final GroupBy groupBy;
  final String groupKey;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([repo, scope.settings]),
      builder: (context, _) {
        final quality = scope.settings.qualityCoefficient;
        RankedGroup? group;
        for (final g in rankGroups(repo.albums, groupBy, useQuality: quality)) {
          if (g.key == groupKey) group = g;
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(group?.label ?? groupBy.label),
            titleTextStyle: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          body: group == null
              ? Center(child: Text('No albums left in this group',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Row(
                        children: [
                          quality
                              ? RatingBadge.quality(group.quality, size: 56)
                              : RatingBadge(group.average, size: 56),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rank #${group.rank} by ${groupBy.label.toLowerCase()}',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                '${quality ? 'Quality ${group.quality.toStringAsFixed(1)} · ' : ''}'
                                'Average ${group.average}/10 · ${group.count} album${group.count == 1 ? '' : 's'}',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(color: theme.colorScheme.outlineVariant),
                    for (final album in group.albums)
                      AlbumTile(
                        album: album,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AlbumEditScreen(album: album)),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
