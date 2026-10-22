import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../logic/ranking.dart';
import '../logic/year_chart.dart';
import 'album_edit_screen.dart';
import 'widgets/album_tile.dart';
import 'widgets/rating_widgets.dart';
import 'widgets/year_chart_card.dart';

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
        // Sorting a single year by year does nothing, so fall back to rating.
        final saved = scope.settings.groupSort;
        final sort = groupBy == GroupBy.year && saved == AlbumSort.year ? AlbumSort.rating : saved;
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
                          Expanded(
                            child: Column(
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
                          ),
                        ],
                      ),
                    ),
                    Divider(color: theme.colorScheme.outlineVariant),
                    if (groupBy != GroupBy.year && group.count > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: YearChartCard(
                          years: yearTimeline(group.albums),
                          settings: scope.settings,
                          onAlbumTap: (album) => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AlbumEditScreen(album: album)),
                          ),
                        ),
                      ),
                    _SortBar(
                      options: [
                        for (final s in AlbumSort.values)
                          if (!(groupBy == GroupBy.year && s == AlbumSort.year)) s
                      ],
                      selected: sort,
                      onChanged: scope.settings.setGroupSort,
                    ),
                    for (final album in sortAlbums(group.albums, sort))
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

class _SortBar extends StatelessWidget {
  const _SortBar({required this.options, required this.selected, required this.onChanged});

  final List<AlbumSort> options;
  final AlbumSort selected;
  final ValueChanged<AlbumSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
      child: Row(
        children: [
          Text('Sort by',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<AlbumSort>(
              key: const ValueKey('group-sort'),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [for (final s in options) ButtonSegment(value: s, label: Text(s.label))],
              selected: {selected},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
