import 'package:flutter/material.dart';

/// Rank label for ranking lists: a gold, silver or bronze crown above the
/// number for ranks 1–3 (ties share a crown), plain "#n" otherwise.
class RankMedal extends StatelessWidget {
  const RankMedal(this.rank, {super.key, this.width = 40});

  final int rank;
  final double width;

  static const _metals = [
    (light: Color(0xFFFFE27A), dark: Color(0xFFD99A00), name: 'Gold'),
    (light: Color(0xFFF2F4F7), dark: Color(0xFF9AA3AE), name: 'Silver'),
    (light: Color(0xFFF1B27E), dark: Color(0xFFA0582A), name: 'Bronze'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rank < 1 || rank > 3) {
      return SizedBox(
        width: width,
        child: Center(
          child: Text('#$rank',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ),
      );
    }
    final metal = _metals[rank - 1];
    return Semantics(
      label: '${metal.name} crown, rank $rank',
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              key: ValueKey('crown-$rank'),
              size: const Size(26, 19),
              painter: _CrownPainter(metal.light, metal.dark),
            ),
            const SizedBox(height: 1),
            Text('$rank',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: Color.lerp(metal.dark, theme.colorScheme.onSurface, 0.15),
                )),
          ],
        ),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter(this.light, this.dark);

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ballR = w * 0.075;
    final top = ballR * 1.6;
    final base = h * 0.80;

    final body = Path()
      ..moveTo(w * 0.10, base)
      ..lineTo(w * 0.05, top + h * 0.10)
      ..lineTo(w * 0.31, top + h * 0.38)
      ..lineTo(w * 0.50, top)
      ..lineTo(w * 0.69, top + h * 0.38)
      ..lineTo(w * 0.95, top + h * 0.10)
      ..lineTo(w * 0.90, base)
      ..close();
    final band = RRect.fromLTRBR(w * 0.09, base - h * 0.02, w * 0.91, h, Radius.circular(h * 0.06));

    final rect = Offset.zero & size;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, dark],
      ).createShader(rect);
    final edge = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(body, fill);
    canvas.drawPath(body, edge);
    canvas.drawRRect(band, fill);
    canvas.drawRRect(band, edge);
    for (final x in [0.05, 0.50, 0.95]) {
      final c = Offset(w * x, (x == 0.5 ? top : top + h * 0.10) - ballR * 0.6);
      canvas.drawCircle(c, ballR, Paint()..color = light);
      canvas.drawCircle(c, ballR, edge);
    }
    canvas.drawCircle(Offset(w * 0.5, base + (h - base) / 2 - h * 0.01), w * 0.05, Paint()..color = dark);
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.light != light || old.dark != dark;
}
