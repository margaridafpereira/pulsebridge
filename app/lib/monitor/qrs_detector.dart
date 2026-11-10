import 'dart:math';

/// Second-order IIR section (RBJ cookbook), direct form I.
class _Biquad {
  _Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory _Biquad.lowPass(double fs, double f0, [double q = 0.7071]) {
    final w = 2 * pi * f0 / fs, alpha = sin(w) / (2 * q), c = cos(w), a0 = 1 + alpha;
    return _Biquad((1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0, -2 * c / a0, (1 - alpha) / a0);
  }

  factory _Biquad.highPass(double fs, double f0, [double q = 0.7071]) {
    final w = 2 * pi * f0 / fs, alpha = sin(w) / (2 * q), c = cos(w), a0 = 1 + alpha;
    return _Biquad((1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0, -2 * c / a0, (1 - alpha) / a0);
  }

  final double b0, b1, b2, a1, a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  double process(double x) {
    final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

/// Real-time QRS detector after Pan & Tompkins, "A real-time QRS detection
/// algorithm", IEEE Trans. Biomed. Eng. 32(3), 1985.
///
/// Pipeline: band-pass 5–15 Hz, five-point derivative, squaring, 150 ms moving
/// window integration, then adaptive signal/noise thresholds with a 200 ms
/// refractory period, T-wave rejection within 360 ms, and search-back when a
/// beat seems missed (no QRS for 166 % of the average RR).
///
/// Feed samples in order with [add]; each detected beat is reported, about
/// 250 ms late, as the sample index of its R peak. Validated against the
/// MIT-BIH annotations in the test suite (SRS-018).
class QrsDetector {
  QrsDetector({required this.sampleRate, required this.onBeat}) {
    _reset();
  }

  final int sampleRate;
  final void Function(int rIndex) onBeat;

  late _Biquad _hp1, _hp2, _lp1, _lp2;
  late List<double> _bp; // band-passed signal, ring buffer of ~1 s for locating R
  late List<double> _derivIn;
  late List<double> _mwiIn;
  double _mwiSum = 0;
  int _n = 0; // samples since the last reset
  int _offset = 0; // absolute index of sample 0 after the last reset

  // Peak search on the integrated signal.
  double _prevMwi = 0;
  bool _rising = false;

  // Adaptive thresholds.
  double _spki = 0, _npki = 0;
  double _learnMax = 0, _learnSum = 0;
  int? _lastQrs; // MWI index of the last QRS
  double _lastQrsSlope = 0;
  final _rr = <int>[];
  final _noisePeaks = <(int, double, double)>[]; // (index, value, slope) since the last QRS

  int get _win => (0.150 * sampleRate).round();
  int get _refractory => (0.200 * sampleRate).round();
  int get _learning => 2 * sampleRate;

  void _reset() {
    _hp1 = _Biquad.highPass(sampleRate.toDouble(), 5);
    _hp2 = _Biquad.highPass(sampleRate.toDouble(), 5);
    _lp1 = _Biquad.lowPass(sampleRate.toDouble(), 15);
    _lp2 = _Biquad.lowPass(sampleRate.toDouble(), 15);
    _bp = List.filled(sampleRate, 0);
    _derivIn = List.filled(5, 0);
    _mwiIn = List.filled(_win, 0);
    _mwiSum = 0;
    _n = 0;
    _prevMwi = 0;
    _rising = false;
    _spki = _npki = _learnMax = _learnSum = 0;
    _lastQrs = null;
    _lastQrsSlope = 0;
    _rr.clear();
    _noisePeaks.clear();
  }

  /// Lost samples break the filters' history: start learning again after them.
  void restart(int nextIndex) {
    _reset();
    _offset = nextIndex;
  }

  void add(int index, int microvolts) {
    if (index != _offset + _n) restart(index);
    final x = microvolts.toDouble();
    final bp = _lp2.process(_lp1.process(_hp2.process(_hp1.process(x))));
    _bp[_n % _bp.length] = bp;

    // Five-point derivative (Pan-Tompkins eq. 8) and squaring.
    _derivIn[_n % 5] = bp;
    double d(int k) => _derivIn[(_n - k) % 5];
    final deriv = _n >= 4 ? (2 * d(0) + d(1) - d(3) - 2 * d(4)) / 8 : 0.0;
    final sq = deriv * deriv;

    _mwiSum += sq - _mwiIn[_n % _win];
    _mwiIn[_n % _win] = sq;
    final mwi = _mwiSum / _win;

    if (_n < _learning) {
      _learnMax = max(_learnMax, mwi);
      _learnSum += mwi;
      if (_n == _learning - 1) {
        _spki = 0.25 * _learnMax;
        _npki = 0.5 * _learnSum / _learning;
      }
    } else {
      _findPeaks(mwi);
      _searchBack();
    }
    _prevMwi = mwi;
    _n++;
  }

  double get _threshold1 => _npki + 0.25 * (_spki - _npki);

  /// Every local maximum of the integrated signal is a peak; the thresholds,
  /// refractory period and T-wave test decide which ones are beats.
  void _findPeaks(double mwi) {
    if (mwi > _prevMwi) {
      _rising = true;
    } else if (_rising && mwi < _prevMwi) {
      _rising = false;
      _classify(_n - 1, _prevMwi);
    }
  }

  void _classify(int idx, double value) {
    final slope = _maxSlope(idx);
    final last = _lastQrs;
    if (value > _threshold1 && (last == null || idx - last > _refractory)) {
      // Within 360 ms of the previous beat, a peak with less than half its
      // slope and well below the running QRS level is taken for a T wave. The
      // amplitude test keeps the close beats of fast atrial fibrillation.
      if (last != null && idx - last < (0.360 * sampleRate) && slope < 0.5 * _lastQrsSlope && value < 0.5 * _spki) {
        _noise(idx, value, slope);
        return;
      }
      _qrs(idx, value, slope, 0.125);
    } else {
      _noise(idx, value, slope);
    }
  }

  void _noise(int idx, double value, double slope) {
    _npki = 0.125 * value + 0.875 * _npki;
    _noisePeaks.add((idx, value, slope));
  }

  void _qrs(int idx, double value, double slope, double weight) {
    _spki = weight * value + (1 - weight) * _spki;
    final last = _lastQrs;
    if (last != null) {
      _rr.add(idx - last);
      if (_rr.length > 8) _rr.removeAt(0);
    }
    _lastQrs = idx;
    _lastQrsSlope = slope;
    _noisePeaks.clear();
    onBeat(_offset + _locateR(idx));
  }

  /// No beat for 166 % of the average RR: take the largest noise peak above
  /// half the threshold as a missed beat.
  void _searchBack() {
    final last = _lastQrs;
    if (last == null || _rr.length < 2) return;
    final avg = _rr.reduce((a, b) => a + b) / _rr.length;
    if (_n - last < 1.66 * avg) return;
    (int, double, double)? best;
    for (final p in _noisePeaks) {
      if (p.$1 - last > _refractory && p.$2 > 0.5 * _threshold1 && (best == null || p.$2 > best.$2)) best = p;
    }
    if (best != null) {
      _npki = (_npki - 0.125 * best.$2) / 0.875; // undo its noise update
      _qrs(best.$1, best.$2, best.$3, 0.25);
    } else {
      _rr.clear(); // a real pause: do not keep searching back across it
    }
  }

  /// Largest band-passed slope in the integration window ending at [idx].
  double _maxSlope(int idx) {
    var m = 0.0;
    for (var k = max(1, idx - _win); k <= idx && idx - k < _bp.length - 1; k++) {
      m = max(m, (_bp[k % _bp.length] - _bp[(k - 1) % _bp.length]).abs());
    }
    return m;
  }

  /// The integration window ends ~75 ms after the QRS, and the filters add
  /// their own delay; the R peak is the largest band-passed excursion in that
  /// span.
  int _locateR(int mwiIdx) {
    final from = max(0, max(mwiIdx - _win - (0.05 * sampleRate).round(), _n - _bp.length + 1));
    var best = mwiIdx;
    var bestVal = -1.0;
    for (var k = from; k <= mwiIdx; k++) {
      final v = _bp[k % _bp.length].abs();
      if (v > bestVal) {
        bestVal = v;
        best = k;
      }
    }
    // Band-pass group delay, measured against the MIT-BIH annotations.
    return max(0, best - (0.056 * sampleRate).round());
  }
}
