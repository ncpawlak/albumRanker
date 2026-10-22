import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/settings_controller.dart';
import '../logic/ranking.dart';
import '../logic/stats.dart';
import '../logic/year_chart.dart';
import '../models/album.dart';
import '../theme/rating_colors.dart';
import 'group_detail_screen.dart';
import 'widgets/rating_widgets.dart';
import 'widgets/year_chart.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final settings = AppScope.of(context).settings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Stats'), centerTitle: false, toolbarHeight: 64),
      body: ListenableBuilder(
        listenable: Listenable.merge([repo, settings]),
        builder: (context, _) {
          final stats = LibraryStats.from(repo.albums);
          if (stats.total == 0) {
            return Center(
              child: Text('Add some albums to see your stats.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Row(
                children: [
                  _NumberCard(label: 'Albums', value: '${stats.total}'),
                  const SizedBox(width: 10),
                  _NumberCard(label: 'Avg rating', badge: stats.average),
                  const SizedBox(width: 10),
                  _NumberCard(label: 'Artists', value: '${stats.artistCount}'),
                  const SizedBox(width: 10),
                  _NumberCard(label: 'Genres', value: '${stats.genreCount}'),
                ],
              ),
              const SizedBox(height: 20),
              _YearChartCard(years: yearTimeline(repo.albums), settings: settings),
              const SizedBox(height: 20),
              const _SectionTitle('Rating spread'),
              _Distribution(stats.distribution),
              const SizedBox(height: 20),
              const _SectionTitle('Most-rated artists'),
              _CountList(stats.topArtists),
              const SizedBox(height: 20),
              const _SectionTitle('Most-rated years'),
              _CountList(stats.topYears),
              const SizedBox(height: 20),
              const _SectionTitle('Most-rated genres'),
              _CountList(stats.topGenres),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          )),
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({required this.label, this.value, this.badge});

  final String label;
  final String? value;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 32,
              child: Center(
                child: badge != null
                    ? RatingBadge(badge!, size: 36)
                    : Text(value ?? '', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ten colored bars, one per star rating, scaled to the most common rating.
class _Distribution extends StatelessWidget {
  const _Distribution(this.counts);

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    const barArea = 110.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var r = Album.minRating; r <= Album.maxRating; r++)
            Expanded(
              child: Semantics(
                label: '$r stars: ${counts[r - 1]} albums',
                child: Column(
                  children: [
                    Text(counts[r - 1] == 0 ? '' : '${counts[r - 1]}',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Container(
                      height: maxCount == 0 ? 0 : 4 + (barArea - 4) * counts[r - 1] / maxCount,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: counts[r - 1] == 0 ? theme.colorScheme.surfaceContainerHigh : ratingColor(r),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$r', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountList extends StatelessWidget {
  const _CountList(this.entries);

  final List<CountEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = entries.isEmpty ? 1 : entries.first.count;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(e.label,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
                            ),
                            Text('${e.count} album${e.count == 1 ? '' : 's'}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.count / maxCount,
                            minHeight: 6,
                            color: ratingColor(e.average),
                            backgroundColor: theme.colorScheme.surfaceContainerHigh,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  RatingBadge(e.average, size: 30),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _YearChartCard extends StatelessWidget {
  const _YearChartCard({required this.years, required this.settings});

  final List<YearPoint> years;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final quality = settings.qualityCoefficient;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Ratings by year')),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: FilterChip(
                key: const ValueKey('chart-fit'),
                label: Text('Fit to screen',
                    style: TextStyle(
                      color: settings.chartCondensed
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    )),
                avatar: Icon(Icons.fit_screen_rounded,
                    size: 18,
                    color: settings.chartCondensed
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant),
                selectedColor: theme.colorScheme.primaryContainer,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selected: settings.chartCondensed,
                onSelected: settings.setChartCondensed,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YearRatingChart(
                years: years,
                condensed: settings.chartCondensed,
                showQuality: quality,
                onYearTap: (year) => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(groupBy: GroupBy.year, groupKey: '$year'),
                )),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _LegendItem(
                      icon: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: ratingColor(8), shape: BoxShape.circle),
                      ),
                      label: 'Album (bigger = more)',
                      style: muted,
                    ),
                    _LegendItem(
                      icon: Container(width: 16, height: 2, color: theme.colorScheme.onSurface),
                      label: 'Average',
                      style: muted,
                    ),
                    if (quality)
                      _LegendItem(
                        icon: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 4,
                              height: 2,
                              margin: const EdgeInsets.only(right: 2),
                              color: theme.colorScheme.primary,
                            ),
                        ]),
                        label: 'Quality score',
                        style: muted,
                      ),
                    Text('Tap a year to open it', style: muted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.icon, required this.label, this.style});

  final Widget icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(width: 5), Text(label, style: style)],
      );
}
