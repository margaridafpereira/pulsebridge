import 'dart:math';

/// Simple beat-to-beat rhythm screening from RR intervals. An indicator for the
/// user, not a diagnosis.
///
/// - Premature beat: RR shorter than 80 % of the median of the last 8 normal RR
///   intervals (the classic prematurity criterion for ectopic beats).
/// - Irregular RR: normalised RMSSD (RMSSD / mean RR) above 0.15 over the last
///   20 beats. Sinus rhythm at rest is usually well below 0.1; atrial
///   fibrillation and frequent ectopy push it far above.
class RhythmAnalyzer {
  static const prematureRatio = 0.8;
  static const irregularThreshold = 0.15;

  final _normal = <int>[];
  final _recent = <int>[];
  int ectopicBeats = 0;

  /// Adds one RR interval; returns true if this beat was premature.
  bool add(int rrMs) {
    var premature = false;
    if (_normal.length >= 8 && rrMs < prematureRatio * _median(_normal.sublist(_normal.length - 8))) {
      premature = true;
      ectopicBeats++;
    } else {
      _normal.add(rrMs);
      if (_normal.length > 32) _normal.removeAt(0);
    }
    _recent.add(rrMs);
    if (_recent.length > 20) _recent.removeAt(0);
    return premature;
  }

  /// Normalised RMSSD over the last 20 beats, or null with too few beats.
  double? get normalizedRmssd {
    if (_recent.length < 20) return null;
    var sum = 0.0;
    for (var i = 1; i < _recent.length; i++) {
      final d = (_recent[i] - _recent[i - 1]).toDouble();
      sum += d * d;
    }
    final rmssd = sqrt(sum / (_recent.length - 1));
    final mean = _recent.reduce((a, b) => a + b) / _recent.length;
    return rmssd / mean;
  }

  bool get irregular => (normalizedRmssd ?? 0) > irregularThreshold;

  void reset() {
    _normal.clear();
    _recent.clear();
    ectopicBeats = 0;
  }

  static double _median(List<int> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid].toDouble() : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
