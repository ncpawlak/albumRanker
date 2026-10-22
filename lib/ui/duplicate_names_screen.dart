import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/album_repository.dart';

/// Lists artists/genres spelled more than one way; tap the spelling to keep.
class DuplicateNamesScreen extends StatelessWidget {
  const DuplicateNamesScreen({super.key});

  Future<void> _merge(BuildContext context, NameVariants v, String keep) async {
    final messenger = ScaffoldMessenger.of(context);
    final n = await AppScope.of(context).repository.mergeName(v.field, keep);
    messenger.showSnackBar(SnackBar(content: Text('Merged into "$keep" ($n album${n == 1 ? '' : 's'} renamed)')));
  }

  Future<void> _mergeAll(BuildContext context, List<NameVariants> all) async {
    final repo = AppScope.of(context).repository;
    final messenger = ScaffoldMessenger.of(context);
    for (final v in all) {
      await repo.mergeName(v.field, v.preferred);
    }
    messenger.showSnackBar(SnackBar(content: Text('Merged ${all.length} name${all.length == 1 ? '' : 's'}')));
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicate names')),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final all = repo.nameVariants();
          if (all.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text('Every artist and genre is spelled one way'),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text('These are counted as separate artists or genres. Tap the spelling to keep.', style: muted),
              const SizedBox(height: 12),
              for (final v in all)
                Card(
                  key: ValueKey('variants-${v.field.name}-${v.preferred}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${v.field.label} · ${v.albumCount} albums', style: muted),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in v.spellings)
                              ActionChip(
                                key: ValueKey('keep-${s.spelling}'),
                                label: Text('${s.spelling}  (${s.count})'),
                                onPressed: () => _merge(context, v, s.spelling),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('merge-all'),
                onPressed: () => _mergeAll(context, all),
                icon: const Icon(Icons.merge_rounded),
                label: const Text('Merge all (keep most-used spelling)'),
              ),
            ],
          );
        },
      ),
    );
  }
}
