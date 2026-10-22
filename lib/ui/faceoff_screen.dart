import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../logic/faceoff.dart';
import '../models/album.dart';
import '../theme/rating_colors.dart';
import 'faceoff_arena.dart';

/// Face-off tab: choose which albums meet, then enter the arena.
class FaceOffScreen extends StatefulWidget {
  const FaceOffScreen({super.key});

  @override
  State<FaceOffScreen> createState() => _FaceOffScreenState();
}

class _FaceOffScreenState extends State<FaceOffScreen> {
  FaceOffMatch _match = FaceOffMatch.tied;
  FaceOffScope _scope = FaceOffScope.all;
  String? _scopeValue;
  final Set<double> _ratings = {};

  /// 0 means endless.
  int _rounds = 10;

  void _start(List<Album> pool) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => FaceOffArena(pool: pool, match: _match, rounds: _rounds == 0 ? null : _rounds),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final selectedLabel = TextStyle(color: theme.colorScheme.surface, fontSize: 13, fontWeight: FontWeight.w600);
    return Scaffold(
      appBar: AppBar(title: const Text('Face-off'), centerTitle: false, toolbarHeight: 64),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final albums = repo.albums;
          final scopeValues = _scope == FaceOffScope.all ? const <String>[] : _scope.valuesIn(albums);
          if (_scopeValue != null && !scopeValues.contains(_scopeValue)) _scopeValue = null;
          final scoped = faceOffPool(albums, scope: _scope, scopeValue: _scopeValue);
          final ratingCounts = <double, int>{};
          for (final a in scoped) {
            ratingCounts[a.rating] = (ratingCounts[a.rating] ?? 0) + 1;
          }
          final ratings = ratingCounts.keys.toList()..sort((a, b) => b.compareTo(a));
          _ratings.removeWhere((r) => !ratingCounts.containsKey(r));
          final pool = faceOffPool(scoped, ratings: _ratings);
          final matchUps = countMatchUps(pool, _match);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text('Pit two albums against each other and pick the better one. '
                        'After each pick you can nudge their ratings.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Match-ups',
                      subtitle: _match.description,
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<FaceOffMatch>(
                          key: const ValueKey('faceoff-match'),
                          showSelectedIcon: false,
                          segments: [
                            for (final m in FaceOffMatch.values) ButtonSegment(value: m, label: Text(m.label)),
                          ],
                          selected: {_match},
                          onSelectionChanged: (s) => setState(() => _match = s.first),
                        ),
                      ),
                    ),
                    _Section(
                      title: 'Rounds',
                      subtitle: _rounds == 0 ? 'Keep going until you stop' : 'Up to $_rounds match-ups',
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          key: const ValueKey('faceoff-rounds'),
                          showSelectedIcon: false,
                          segments: [
                            for (final n in const [5, 10, 20, 0])
                              ButtonSegment(value: n, label: Text(n == 0 ? '∞' : '$n')),
                          ],
                          selected: {_rounds},
                          onSelectionChanged: (s) => setState(() => _rounds = s.first),
                        ),
                      ),
                    ),
                    _Section(
                      title: 'Only',
                      subtitle: 'Keep it to one artist, genre or year',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<FaceOffScope>(
                              key: const ValueKey('faceoff-scope'),
                              showSelectedIcon: false,
                              segments: [
                                for (final s in FaceOffScope.values) ButtonSegment(value: s, label: Text(s.label)),
                              ],
                              selected: {_scope},
                              onSelectionChanged: (s) => setState(() {
                                _scope = s.first;
                                _scopeValue = null;
                              }),
                            ),
                          ),
                          if (_scope != FaceOffScope.all) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey('faceoff-scope-value-${_scope.name}'),
                              initialValue: _scopeValue,
                              isExpanded: true,
                              hint: Text('Choose ${_scope.label.toLowerCase()}'),
                              items: [for (final v in scopeValues) DropdownMenuItem(value: v, child: Text(v))],
                              onChanged: (v) => setState(() => _scopeValue = v),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _Section(
                      title: 'Ratings',
                      subtitle: _ratings.isEmpty ? 'All ratings — tap to focus on some' : '${_ratings.length} selected',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            key: const ValueKey('rating-chip-all'),
                            label: const Text('All'),
                            selected: _ratings.isEmpty,
                            labelStyle: _ratings.isEmpty ? selectedLabel : null,
                            onSelected: (_) => setState(_ratings.clear),
                          ),
                          for (final r in ratings)
                            FilterChip(
                              key: ValueKey('rating-chip-${formatRating(r)}'),
                              avatar: CircleAvatar(backgroundColor: ratingColor(r), radius: 6),
                              label: Text('${formatRating(r)}  ·  ${ratingCounts[r]}'),
                              selected: _ratings.contains(r),
                              labelStyle: _ratings.contains(r) ? selectedLabel : null,
                              showCheckmark: false,
                              onSelected: (on) => setState(() => on ? _ratings.add(r) : _ratings.remove(r)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    children: [
                      Text(
                        matchUps == 0
                            ? (_match == FaceOffMatch.tied
                                ? 'No tied albums here — try "Within ½" or more ratings'
                                : 'Not enough albums in this selection')
                            : '$matchUps match-up${matchUps == 1 ? '' : 's'} ready · ${pool.length} albums',
                        key: const ValueKey('faceoff-count'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 10),
                      _StartButton(enabled: matchUps > 0, onPressed: () => _start(pool)),
                    ],
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: 58,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF5B8CFF), Color(0xFF8A5BFF)]),
          ),
          child: InkWell(
            key: const ValueKey('faceoff-start'),
            onTap: enabled ? onPressed : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, color: Colors.white),
                SizedBox(width: 6),
                Text('Start face-off',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
