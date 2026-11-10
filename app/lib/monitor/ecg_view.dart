import 'package:flutter/material.dart';

import 'ecg_buffer.dart';

/// Real-time ECG trace in sweep mode on a standard paper grid
/// (large squares 0.2 s × 0.5 mV, small squares 0.04 s × 0.1 mV).
class EcgView extends StatelessWidget {
  const EcgView({super.key, required this.buffer, this.millivoltsShown = 4, this.dimmed = false});

  final EcgBuffer buffer;

  /// Vertical range of the trace, centred on 0 mV.
  final double millivoltsShown;

  /// Grey out the trace when it is not live data.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _EcgPainter(buffer, millivoltsShown, dimmed),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter(this.buffer, this.millivoltsShown, this.dimmed) : super(repaint: buffer);

  final EcgBuffer buffer;
  final double millivoltsShown;
  final bool dimmed;

  static const _background = Color(0xFF0B1014);
  static const _gridMinor = Color(0xFF16232B);
  static const _gridMajor = Color(0xFF223843);
  static const _trace = Color(0xFF3DDC84);
  static const _traceDimmed = Color(0xFF5B6B73);

  @override
  void paint(Canvas canvas, Size size) {
    // Tall ectopic beats must not spill over the card header.
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    _paintGrid(canvas, size);
    if (!buffer.hasData) return;

    final capacity = buffer.capacity;
    final dx = size.width / capacity;
    final pxPerUv = size.height / (millivoltsShown * 1000);
    final mid = size.height / 2;
    // Blank gap just ahead of the cursor, where old data is being replaced.
    final erase = (buffer.sampleRate * 0.15).round();
    final cursor = buffer.cursor;

    final path = Path();
    var penDown = false;
    for (var i = 0; i < capacity; i++) {
      final ahead = (i - cursor) % capacity;
      final value = buffer.valueAt(i);
      if (value == EcgBuffer.gap || ahead < erase) {
        penDown = false;
        continue;
      }
      final point = Offset(i * dx, mid - value * pxPerUv);
      if (penDown && i > 0) {
        path.lineTo(point.dx, point.dy);
      } else {
        path.moveTo(point.dx, point.dy);
        penDown = true;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = dimmed ? _traceDimmed : _trace
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintGrid(Canvas canvas, Size size) {
    final seconds = buffer.capacity / buffer.sampleRate;
    final pxPerSecond = size.width / seconds;
    final pxPerMv = size.height / millivoltsShown;
    final minor = Paint()..color = _gridMinor;
    final major = Paint()..color = _gridMajor;

    for (var t = 0, x = 0.0; x <= size.width; t++, x = t * 0.04 * pxPerSecond) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), t % 5 == 0 ? major : minor);
    }
    final mid = size.height / 2;
    for (var k = 0; k * 0.1 * pxPerMv <= mid; k++) {
      final y = k * 0.1 * pxPerMv;
      final paint = k % 5 == 0 ? major : minor;
      canvas.drawLine(Offset(0, mid - y), Offset(size.width, mid - y), paint);
      canvas.drawLine(Offset(0, mid + y), Offset(size.width, mid + y), paint);
    }
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.dimmed != dimmed || old.millivoltsShown != millivoltsShown;
}
