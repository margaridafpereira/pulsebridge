import 'dart:math';

import 'package:flutter/foundation.dart';

/// Sweep-mode ECG buffer, like a bedside monitor: a fixed time window that is
/// overwritten from left to right. Lost samples are stored as [gap] so the
/// trace shows a break instead of a misleading straight line (HAZ-002).
///
/// With [filter] on, a 0.5 Hz high-pass ("monitor mode") removes baseline
/// wander for display. Recordings keep the raw signal.
class EcgBuffer extends ChangeNotifier {
  EcgBuffer({this.windowSeconds = 5, int sampleRate = 250, this.filter = true}) {
    _resize(sampleRate);
  }

  static const gap = -0x80000000;
  static const highPassHz = 0.5;

  final int windowSeconds;
  final bool filter;
  late int sampleRate;
  late Int32List _values;
  late double _alpha;
  int _writeIndex = 0; // absolute index of the next sample to write
  bool _hasData = false;
  double? _prevX;
  double _prevY = 0;

  int get capacity => _values.length;

  /// Position of the sweep cursor within the window.
  int get cursor => _writeIndex % capacity;

  bool get hasData => _hasData;

  int valueAt(int position) => _values[position];

  void setSampleRate(int rate) {
    if (rate != sampleRate) {
      _resize(rate);
      notifyListeners();
    }
  }

  void addChunk(int firstIndex, List<int> samples) {
    if (firstIndex < _writeIndex) {
      // The device restarted its count: a new stream.
      _writeIndex = firstIndex;
      _prevX = null;
    } else if (firstIndex > _writeIndex) {
      _fill(firstIndex - _writeIndex, gap);
      _prevX = null; // restart the filter after a gap
    }
    for (final sample in samples) {
      _values[_writeIndex % capacity] = filter ? _highPass(sample.toDouble()) : sample;
      _writeIndex++;
    }
    _hasData = true;
    notifyListeners();
  }

  void clear() {
    _values.fillRange(0, capacity, gap);
    _writeIndex = 0;
    _hasData = false;
    _prevX = null;
    notifyListeners();
  }

  // First-order IIR high-pass: y[n] = a * (y[n-1] + x[n] - x[n-1]).
  int _highPass(double x) {
    final prev = _prevX;
    _prevY = prev == null ? 0 : _alpha * (_prevY + x - prev);
    _prevX = x;
    return _prevY.round();
  }

  void _fill(int count, int value) {
    for (var i = 0; i < count.clamp(0, capacity); i++) {
      _values[(_writeIndex + i) % capacity] = value;
    }
    _writeIndex += count;
  }

  void _resize(int rate) {
    sampleRate = rate;
    final rc = 1 / (2 * pi * highPassHz);
    _alpha = rc / (rc + 1 / rate);
    _values = Int32List(rate * windowSeconds)..fillRange(0, rate * windowSeconds, gap);
    _writeIndex = 0;
    _hasData = false;
    _prevX = null;
  }
}
