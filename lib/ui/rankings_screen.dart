import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../logic/ranking.dart';
import 'group_detail_screen.dart';
import 'widgets/rating_widgets.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  GroupBy _groupBy = GroupBy.artist;
  int _minAlbums = 1;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rankings'), centerTitle: false, toolbarHeight: 64),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final groups = rankGroups(repo.albums, _groupBy, minAlbums: _minAlbums);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<GroupBy>(
                    showSelectedIcon: false,
                    segments: [
                      for (final g in GroupBy.values) ButtonSegment(value: g, label: Text(g.label)),
                    ],
                    selected: {_groupBy},
                    onSelectionChanged: (s) => setState(() => _groupBy = s.first),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                child: Row(
                  children: [
                    Text(
                      '${groups.length} ${_groupBy.label.toLowerCase()}${groups.length == 1 ? '' : 's'}',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Text('Min albums',
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            repo.albums.isEmpty
                                ? 'Add some albums to see rankings.'
                                : 'No groups have at least $_minAlbums albums.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: groups.length,
                        itemBuilder: (context, i) => _GroupRow(
                          group: groups[i],
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(groupBy: _groupBy, groupKey: groups[i].key),
                          )),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.onTap});

  final RankedGroup group;
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
                    '${group.count} album${group.count == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            RatingBadge(group.average, size: 38),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
