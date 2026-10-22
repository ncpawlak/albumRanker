import 'package:flutter/material.dart';

import '../../data/settings_controller.dart';
import '../../logic/year_chart.dart';
import '../../models/album.dart';
import '../../theme/rating_colors.dart';
import 'year_chart.dart';

/// Titled "Ratings by year" card with the Fit-to-screen toggle and a legend.
/// Pass [onYearTap] to open a whole year, or [onAlbumTap] to open the album
/// under a tapped dot.
class YearChartCard extends StatelessWidget {
  const YearChartCard({
    super.key,
    required this.years,
    required this.settings,
    this.showQuality = false,
    this.onYearTap,
    this.onAlbumTap,
    this.translucent = false,
  });

  final List<YearPoint> years;
  final SettingsController settings;
  final bool showQuality;
  final ValueChanged<int>? onYearTap;
  final ValueChanged<Album>? onAlbumTap;

  /// Lets a background image show through the card.
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    final condensed = settings.chartCondensed;
    final onChip = condensed ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('RATINGS BY YEAR',
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: FilterChip(
                key: const ValueKey('chart-fit'),
                label: Text('Fit to screen', style: TextStyle(color: onChip)),
                avatar: Icon(Icons.fit_screen_rounded, size: 18, color: onChip),
                selectedColor: cs.primaryContainer,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selected: condensed,
                onSelected: settings.setChartCondensed,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
          decoration: BoxDecoration(
              color: translucent ? cs.surfaceContainer.withValues(alpha: 0.55) : cs.surfaceContainer,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YearRatingChart(
                years: years,
                condensed: condensed,
                showQuality: showQuality,
                onYearTap: onYearTap,
                onAlbumTap: onAlbumTap,
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
                      icon: Container(width: 16, height: 2, color: cs.onSurface),
                      label: 'Average',
                      style: muted,
                    ),
                    if (showQuality)
                      _LegendItem(
                        icon: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < 3; i++)
                            Container(width: 4, height: 2, margin: const EdgeInsets.only(right: 2), color: cs.primary),
                        ]),
                        label: 'Quality score',
                        style: muted,
                      ),
                    if (onAlbumTap != null)
                      Text('Tap a dot to open the album', style: muted)
                    else if (onYearTap != null)
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
