import 'package:flutter/material.dart';

/// Heart-rate trend: a line over time with the alarm limits as a shaded band.
/// [points] are (seconds, bpm) pairs in increasing time order.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.low,
    required this.high,
    this.spanSeconds,
    this.showAxis = false,
    this.color = const Color(0xFF3DDC84),
  });

  final List<(double, int)> points;
  final int low;
  final int high;

  /// Width of the time axis; defaults to the data's own span.
  final double? spanSeconds;
  final bool showAxis;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _TrendPainter(points, low, high, spanSeconds, showAxis, color, Theme.of(context).textTheme.bodySmall!),
        child: const SizedBox.expand(),
      );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.low, this.high, this.span, this.showAxis, this.color, this.labelStyle);

  final List<(double, int)> points;
  final int low;
  final int high;
  final double? span;
  final bool showAxis;
  final Color color;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final left = showAxis ? 32.0 : 0.0;
    final bottom = showAxis ? size.height - 18 : size.height;
    final plot = Rect.fromLTRB(left, 4, size.width, bottom);

    var minY = low - 10.0, maxY = high + 10.0;
    for (final (_, bpm) in points) {
      if (bpm < minY) minY = bpm - 5.0;
      if (bpm > maxY) maxY = bpm + 5.0;
    }
    double y(num bpm) => plot.bottom - (bpm - minY) / (maxY - minY) * plot.height;

    // Normal band between the limits.
    canvas.drawRect(
      Rect.fromLTRB(plot.left, y(high), plot.right, y(low)),
      Paint()..color = color.withValues(alpha: 0.08),
    );
    final limitPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(plot.left, y(high)), Offset(plot.right, y(high)), limitPaint);
    canvas.drawLine(Offset(plot.left, y(low)), Offset(plot.right, y(low)), limitPaint);

    if (showAxis) {
      for (final v in [low, high]) {
        _label(canvas, '$v', Offset(0, y(v) - 7));
      }
    }
    if (points.length < 2) return;

    final t0 = points.first.$1;
    final width = span ?? (points.last.$1 - t0).clamp(1, double.infinity);
    final start = span != null ? points.last.$1 - width : t0;
    double x(double t) => plot.left + (t - start) / width * plot.width;

    final path = Path();
    var first = true;
    for (final (t, bpm) in points) {
      if (t < start) continue;
      final p = Offset(x(t), y(bpm));
      first ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      first = false;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    if (showAxis) {
      _label(canvas, _time(start - t0), Offset(plot.left, plot.bottom + 4));
      final end = _time(start + width - t0);
      _label(canvas, end, Offset(plot.right - end.length * 7.0, plot.bottom + 4));
    }
  }

  void _label(Canvas canvas, String text, Offset at) {
    (TextPainter(text: TextSpan(text: text, style: labelStyle), textDirection: TextDirection.ltr)..layout())
        .paint(canvas, at);
  }

  static String _time(double seconds) {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.low != low || old.high != high || old.span != span;
}
