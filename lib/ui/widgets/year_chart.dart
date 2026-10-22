import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../logic/year_chart.dart';
import '../../models/album.dart';
import '../../theme/rating_colors.dart';

/// Ratings-by-year chart: a dot per album (stacked dots grow and show a count),
/// a solid line through each year's whole-number average and, when [showQuality]
/// is on, a dashed line through each year's quality score. Empty years keep
/// their slot on the timeline and break both lines.
class YearRatingChart extends StatefulWidget {
  const YearRatingChart({
    super.key,
    required this.years,
    required this.condensed,
    required this.showQuality,
    this.onYearTap,
    this.onAlbumTap,
  });

  final List<YearPoint> years;
  final bool condensed;
  final bool showQuality;
  final ValueChanged<int>? onYearTap;

  /// When set, tapping a dot opens its album (a picker if several share it)
  /// instead of calling [onYearTap].
  final ValueChanged<Album>? onAlbumTap;

  static const scrollSlotWidth = 44.0;
  static const chartHeight = 230.0;

  @override
  State<YearRatingChart> createState() => _YearRatingChartState();
}

class _YearRatingChartState extends State<YearRatingChart> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _jumpToLatest();
  }

  @override
  void didUpdateWidget(YearRatingChart old) {
    super.didUpdateWidget(old);
    if (old.condensed && !widget.condensed) _jumpToLatest();
  }

  /// Scrolling view opens on the most recent years.
  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the album whose dot row is nearest the tap; several albums sharing
  /// that dot get a picker sheet.
  Future<void> _openAlbumAt(YearPoint point, double dy) async {
    int? nearest;
    var best = double.infinity;
    for (final r in point.stacks.keys) {
      final dist = (dy - _Geometry.y(r)).abs();
      if (dist < best) {
        best = dist;
        nearest = r;
      }
    }
    if (nearest == null || best > _Geometry.step * 0.75) return;
    final albums = [for (final a in point.albums) if (a.rating == nearest) a]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final open = widget.onAlbumTap!;
    if (albums.length == 1) {
      open(albums.single);
      return;
    }
    final picked = await showModalBottomSheet<Album>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${point.year} · $nearest stars', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final a in albums)
              ListTile(
                title: Text(a.title),
                subtitle: Text(a.artist),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(a),
              ),
          ],
        ),
      ),
    );
    if (picked != null) open(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _ChartColors.of(theme);
    const height = YearRatingChart.chartHeight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(size: const Size(22, height), painter: _AxisPainter(colors)),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final n = widget.years.length;
            final viewport = constraints.maxWidth;
            final slot = widget.condensed ? viewport / n : math.max(viewport / n, YearRatingChart.scrollSlotWidth);
            final painter = _ChartPainter(
              years: widget.years,
              slot: slot,
              condensed: widget.condensed,
              showQuality: widget.showQuality,
              colors: colors,
            );
            final chart = GestureDetector(
              key: const ValueKey('year-chart'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final i = (d.localPosition.dx / slot).floor();
                if (i < 0 || i >= n || widget.years[i].isEmpty) return;
                if (widget.onAlbumTap != null) {
                  _openAlbumAt(widget.years[i], d.localPosition.dy);
                } else {
                  widget.onYearTap?.call(widget.years[i].year);
                }
              },
              child: CustomPaint(size: Size(slot * n, height), painter: painter),
            );
            if (widget.condensed) return chart;
            return SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: chart,
            );
          }),
        ),
      ],
    );
  }
}

class _ChartColors {
  const _ChartColors({
    required this.grid,
    required this.label,
    required this.mutedLabel,
    required this.average,
    required this.quality,
    required this.dotEdge,
    required this.emptyBand,
  });

  factory _ChartColors.of(ThemeData theme) {
    final cs = theme.colorScheme;
    return _ChartColors(
      grid: cs.outlineVariant.withValues(alpha: 0.6),
      label: cs.onSurfaceVariant,
      mutedLabel: cs.onSurfaceVariant.withValues(alpha: 0.45),
      average: cs.onSurface,
      quality: cs.primary,
      dotEdge: cs.surfaceContainer,
      emptyBand: cs.onSurface.withValues(alpha: 0.03),
    );
  }

  final Color grid, label, mutedLabel, average, quality, dotEdge, emptyBand;
}

/// Shared vertical layout so the fixed y-axis lines up with the scrolling plot.
class _Geometry {
  static const top = 12.0;
  static const labelBand = 24.0;
  static const bottom = YearRatingChart.chartHeight - labelBand - 6;

  static double y(num rating) => top + (10 - rating) / 9 * (bottom - top);
  static double get step => (bottom - top) / 9;
}

class _AxisPainter extends CustomPainter {
  const _AxisPainter(this.colors);

  final _ChartColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (var r = 2; r <= 10; r += 2) {
      _drawText(canvas, '$r', Offset(size.width - 6, _Geometry.y(r)), colors.label, 10.5,
          align: TextAlign.right);
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) => old.colors.label != colors.label;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.years,
    required this.slot,
    required this.condensed,
    required this.showQuality,
    required this.colors,
  });

  final List<YearPoint> years;
  final double slot;
  final bool condensed;
  final bool showQuality;
  final _ChartColors colors;

  double _x(int i) => slot * i + slot / 2;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintDots(canvas);
    _paintLine(canvas, [for (final y in years) y.average?.toDouble()],
        Paint()
          ..color = colors.average.withValues(alpha: 0.85)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
        dashed: false);
    if (showQuality) {
      _paintLine(canvas, [for (final y in years) y.quality],
          Paint()
            ..color = colors.quality
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
          dashed: true);
    }
    _paintYearLabels(canvas);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    for (var r = 1; r <= 10; r++) {
      final y = _Geometry.y(r);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid..strokeWidth = r.isEven ? 1 : 0.5);
    }
    final band = Paint()..color = colors.emptyBand;
    for (var i = 0; i < years.length; i++) {
      if (!years[i].isEmpty) continue;
      canvas.drawRect(Rect.fromLTRB(slot * i, _Geometry.top - 6, slot * (i + 1), _Geometry.bottom + 6), band);
    }
  }

  void _paintDots(Canvas canvas) {
    final base = condensed ? (slot * 0.32).clamp(2.5, 5.5).toDouble() : 5.5;
    final maxR = math.min(_Geometry.step * 0.55, condensed ? math.max(base, slot * 0.7) : 11.0);
    final edge = Paint()
      ..color = colors.dotEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = condensed && slot < 8 ? 0.5 : 1.2;
    for (var i = 0; i < years.length; i++) {
      final stacks = years[i].stacks.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final s in stacks) {
        final r = math.min(base * (1 + 0.5 * (math.sqrt(s.value) - 1)), maxR);
        final c = Offset(_x(i), _Geometry.y(s.key));
        canvas.drawCircle(c, r, Paint()..color = ratingColor(s.key).withValues(alpha: 0.9));
        canvas.drawCircle(c, r, edge);
        if (s.value > 1 && r >= 7.5) {
          _drawText(canvas, '${s.value}', c, onRatingColor(s.key), r >= 9 ? 9.5 : 8.5, bold: true);
        }
      }
    }
  }

  /// Connects consecutive years that have values; a null (empty year) breaks the line.
  void _paintLine(Canvas canvas, List<double?> values, Paint paint, {required bool dashed}) {
    final path = Path();
    var drawing = false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        drawing = false;
        continue;
      }
      final p = Offset(_x(i), _Geometry.y(v));
      drawing ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
      drawing = true;
      canvas.drawCircle(p, condensed && slot < 10 ? 1.6 : 2.6, Paint()..color = paint.color);
    }
    canvas.drawPath(dashed ? _dash(path, 5, 4) : path, paint);
  }

  Path _dash(Path source, double on, double off) {
    final out = Path();
    for (final ui.PathMetric m in source.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += on + off) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
      }
    }
    return out;
  }

  void _paintYearLabels(Canvas canvas) {
    final labelY = _Geometry.bottom + 6 + _Geometry.labelBand / 2;
    final width = slot * years.length;
    final indexes = condensed
        ? condensedLabelIndexes([for (final y in years) y.year], 42 / slot)
        : List.generate(years.length, (i) => i);
    for (final i in indexes) {
      // Keep the first and last labels inside the chart edges.
      final x = _x(i).clamp(15.0, math.max(15.0, width - 15)).toDouble();
      _drawText(canvas, '${years[i].year}', Offset(x, labelY),
          years[i].isEmpty ? colors.mutedLabel : colors.label, 10.5);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.years != years ||
      old.slot != slot ||
      old.condensed != condensed ||
      old.showQuality != showQuality ||
      old.colors.average != colors.average;
}

void _drawText(Canvas canvas, String text, Offset center, Color color, double size,
    {bool bold = false, TextAlign align = TextAlign.center}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.right => center.dx - tp.width,
    _ => center.dx - tp.width / 2,
  };
  tp.paint(canvas, Offset(dx, center.dy - tp.height / 2));
}
