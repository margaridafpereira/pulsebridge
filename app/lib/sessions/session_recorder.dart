import 'dart:typed_data';

import 'session.dart';

/// Builds a [Session] and its raw ECG while recording. Raw samples are kept
/// unfiltered; lost samples become [SessionEcg.gap] so review shows the break.
class SessionRecorder {
  SessionRecorder({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Hard cap so a forgotten recording cannot fill the phone: 4 h at 250 Hz.
  static const maxSamples = 250 * 60 * 60 * 4;

  final DateTime Function() _clock;
  DateTime? _start;
  int _sampleRate = 250;
  String _deviceId = 'unknown';
  final _ecg = BytesBuilder(copy: false);
  int _nextIndex = 0;
  int _written = 0;
  int _lost = 0;
  final _heartRate = <HeartRatePoint>[];
  final _events = <SessionEvent>[];

  bool get isRecording => _start != null;
  DateTime? get startedAt => _start;

  void start({required int sampleRate, required String deviceId}) {
    _start = _clock();
    _sampleRate = sampleRate;
    _deviceId = deviceId;
    _ecg.clear();
    _nextIndex = 0;
    _written = 0;
    _lost = 0;
    _heartRate.clear();
    _events.clear();
    addEvent(SessionEventKind.info, 'Recording started');
  }

  void addEcg(int firstIndex, List<int> samples) {
    if (!isRecording) return;
    if (firstIndex < _nextIndex) {
      _nextIndex = firstIndex; // stream restarted after a reconnect
    } else if (firstIndex > _nextIndex) {
      final missing = firstIndex - _nextIndex;
      _lost += missing;
      _append(List.filled(missing, SessionEcg.gap));
    }
    _append(samples);
    _nextIndex = firstIndex + samples.length;
  }

  void addHeartRate(int bpm) {
    if (isRecording) _heartRate.add(HeartRatePoint(_elapsedMs, bpm));
  }

  void addEvent(SessionEventKind kind, String text) {
    if (isRecording) _events.add(SessionEvent(_elapsedMs, kind, text));
  }

  /// Ends the recording. Returns null if it was empty.
  (Session, Uint8List)? finish({required int ectopicBeats}) {
    if (!isRecording) return null;
    addEvent(SessionEventKind.info, 'Recording stopped');
    final start = _start!;
    final session = Session(
      id: '${start.millisecondsSinceEpoch}',
      start: start,
      duration: _clock().difference(start),
      sampleRate: _sampleRate,
      deviceId: _deviceId,
      heartRate: List.of(_heartRate),
      events: List.of(_events),
      ectopicBeats: ectopicBeats,
      lostSamples: _lost,
      totalSamples: _written,
    );
    final ecg = _ecg.takeBytes();
    _start = null;
    // Heart-rate-only sensors record no ECG, and that is still a recording.
    return _written == 0 && _heartRate.isEmpty ? null : (session, ecg);
  }

  int get _elapsedMs => _clock().difference(_start!).inMilliseconds;

  void _append(List<int> samples) {
    final room = maxSamples - _written;
    if (room <= 0) return;
    final n = samples.length < room ? samples.length : room;
    final bytes = ByteData(n * 2);
    for (var i = 0; i < n; i++) {
      bytes.setInt16(i * 2, samples[i].clamp(-32768, 32767), Endian.little);
    }
    _ecg.add(bytes.buffer.asUint8List());
    _written += n;
  }
}
