import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../logic/ranking.dart';
import 'album_edit_screen.dart';
import 'group_detail_screen.dart';
import 'widgets/album_tile.dart';
import 'widgets/rating_widgets.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

/// Rankings tabs: the four group-by modes plus a leaderboard of single albums.
enum _RankView {
  year(GroupBy.year),
  decade(GroupBy.decade),
  genre(GroupBy.genre),
  artist(GroupBy.artist),
  albums(null);

  const _RankView(this.groupBy);
  final GroupBy? groupBy;

  String get label => groupBy?.label ?? 'Albums';
}

class _RankingsScreenState extends State<RankingsScreen> {
  _RankView _view = _RankView.artist;
  int _minAlbums = 1;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final settings = scope.settings;
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Rankings'), centerTitle: false, toolbarHeight: 64),
      body: ListenableBuilder(
        listenable: Listenable.merge([repo, settings]),
        builder: (context, _) {
          final quality = settings.qualityCoefficient;
          final groupBy = _view.groupBy;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_RankView>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
                    ),
                    segments: [
                      for (final v in _RankView.values)
                        ButtonSegment(
                          value: v,
                          label: FittedBox(fit: BoxFit.scaleDown, child: Text(v.label, maxLines: 1)),
                        ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (s) => setState(() => _view = s.first),
                  ),
                ),
              ),
              if (groupBy == null)
                Expanded(child: _AlbumLeaderboard(muted: muted))
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quality coefficient', style: theme.textTheme.titleSmall),
                            Text(
                              quality ? 'Rewards groups with many good albums' : 'Ranking by plain average',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const ValueKey('quality-toggle'),
                        value: quality,
                        onChanged: settings.setQualityCoefficient,
                      ),
                    ],
                  ),
                ),
                Expanded(child: _groupList(context, groupBy, quality, muted)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _groupList(BuildContext context, GroupBy groupBy, bool quality, TextStyle? muted) {
    final repo = AppScope.of(context).repository;
    final groups = rankGroups(repo.albums, groupBy, minAlbums: _minAlbums, useQuality: quality);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              Text('${groups.length} ${groupBy.label.toLowerCase()}${groups.length == 1 ? '' : 's'}', style: muted),
              const Spacer(),
              Text('Min albums', style: muted),
              const SizedBox(width: 4),
              DropdownButton<int>(
                value: _minAlbums,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                items: [for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                onChanged: (v) => setState(() => _minAlbums = v ?? 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? _EmptyMessage(
                  repo.albums.isEmpty ? 'Add some albums to see rankings.' : 'No groups have at least $_minAlbums albums.')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: groups.length,
                  itemBuilder: (context, i) => _GroupRow(
                    group: groups[i],
                    quality: quality,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(groupBy: groupBy, groupKey: groups[i].key),
                    )),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AlbumLeaderboard extends StatelessWidget {
  const _AlbumLeaderboard({required this.muted});

  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ranked = rankAlbums(AppScope.of(context).repository.albums);
    if (ranked.isEmpty) return const _EmptyMessage('Add some albums to see rankings.');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: ranked.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('${ranked.length} album${ranked.length == 1 ? '' : 's'} by your rating', style: muted),
          );
        }
        final r = ranked[i - 1];
        return AlbumTile(
          album: r.album,
          leading: SizedBox(
            width: 36,
            child: Center(
              child: Text(
                '#${r.rank}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: r.rank <= 3 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AlbumEditScreen(album: r.album)),
          ),
        );
      },
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text,
              textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.quality, required this.onTap});

  final RankedGroup group;
  final bool quality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top3 = group.rank <= 3;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant))),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '#${group.rank}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: top3 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(
                    '${group.count} album${group.count == 1 ? '' : 's'}'
                    '${quality ? ' · avg ${group.average}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            quality
                ? RatingBadge.quality(group.quality, size: 38)
                : RatingBadge(group.average, size: 38),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
