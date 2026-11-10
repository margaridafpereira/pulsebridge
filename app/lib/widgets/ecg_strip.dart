import 'package:flutter/material.dart';

import '../sessions/session.dart';

/// A window of a recorded ECG on paper grid, for review. Lost samples are
/// drawn as breaks. Baseline wander is removed with the same 0.5 Hz high-pass
/// as the live view, so the two look alike.
class EcgStrip extends StatelessWidget {
  const EcgStrip({super.key, required this.ecg, required this.startSample, this.seconds = 6});

  final SessionEcg ecg;
  final int startSample;
  final int seconds;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _StripPainter(ecg, startSample, seconds),
        child: const SizedBox.expand(),
      );
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.ecg, this.start, this.seconds);

  final SessionEcg ecg;
  final int start;
  final int seconds;

  static const _millivolts = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF5F5));
    final pxPerSecond = size.width / seconds;
    final pxPerMv = size.height / _millivolts;
    final minor = Paint()..color = const Color(0xFFF7C9C9);
    final major = Paint()..color = const Color(0xFFE79A9A);
    for (var i = 0; i * 0.04 * pxPerSecond <= size.width; i++) {
      final x = i * 0.04 * pxPerSecond;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    for (var i = 0; i * 0.1 * pxPerMv <= size.height; i++) {
      final y = i * 0.1 * pxPerMv;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i % 5 == 0 ? major : minor);
    }

    final count = ecg.sampleRate * seconds;
    final alpha = 1 / (1 + 2 * 3.141592653589793 * 0.5 / ecg.sampleRate);
    final path = Path();
    double? prevX;
    var prevY = 0.0;
    var penDown = false;
    // Warm the filter up on the second before the window so the trace starts settled.
    final warmUp = (start - ecg.sampleRate).clamp(0, ecg.samples.length);
    for (var i = warmUp; i < start + count && i < ecg.samples.length; i++) {
      final raw = ecg.samples[i];
      if (raw == SessionEcg.gap) {
        prevX = null;
        penDown = false;
        continue;
      }
      prevY = prevX == null ? 0 : alpha * (prevY + raw - prevX);
      prevX = raw.toDouble();
      if (i < start) continue;
      final p = Offset((i - start) / ecg.sampleRate * pxPerSecond, size.height / 2 - prevY / 1000 * pxPerMv);
      penDown ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
      penDown = true;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF1B1B1F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StripPainter old) => old.ecg != ecg || old.start != start || old.seconds != seconds;
}
