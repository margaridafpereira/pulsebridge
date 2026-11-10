import 'dart:async';
import 'dart:typed_data';

import 'package:device_link/device_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sessions/session.dart' as rec;
import '../sessions/session_recorder.dart';
import '../sessions/sessions_provider.dart';
import '../settings/settings.dart';
import 'ecg_buffer.dart';
import 'qrs_detector.dart';
import '../web/demo_device.dart';
import 'rhythm.dart';

/// Heart-rate limits outside which the app raises an alert (SRS-011).
class HeartRateLimits {
  const HeartRateLimits({this.low = 40, this.high = 130});
  final int low;
  final int high;
}

class TrendPoint {
  const TrendPoint(this.at, this.bpm);
  final DateTime at;
  final int bpm;
}

/// Where the displayed heart rate comes from.
enum HeartRateSource {
  /// Beats found in the ECG by the on-phone QRS detector.
  ecg,

  /// The rate the device reports (Bluetooth sensors, or no ECG arriving).
  device,
}

class MonitorState {
  const MonitorState({
    this.sessionActive = false,
    this.link = LinkState.disconnected,
    this.linkReason,
    this.device,
    this.streaming = false,
    this.recordingSince,
    this.bpm,
    this.hrSource,
    this.trend = const [],
    this.ectopicBeats = 0,
    this.irregular = false,
    this.symptoms = 0,
    this.battery,
    this.alarms = const {},
    this.stats,
    this.limits = const HeartRateLimits(),
    this.savedSession,
    this.firmware,
  });

  /// The user asked to connect and has not disconnected; the link may still be
  /// down and reconnecting.
  final bool sessionActive;
  final LinkState link;
  final String? linkReason;
  final DeviceInfo? device;
  final bool streaming;
  final DateTime? recordingSince;
  final int? bpm;
  final HeartRateSource? hrSource;

  /// Heart rate over the last [MonitorController.trendWindow].
  final List<TrendPoint> trend;
  final int ectopicBeats;
  final bool irregular;

  /// Symptoms marked during the current recording.
  final int symptoms;
  final int? battery;
  final Set<DeviceAlarm> alarms;
  final LinkStats? stats;
  final HeartRateLimits limits;

  /// The most recently saved recording, for a confirmation message.
  final rec.Session? savedSession;

  /// The latest firmware update progress, if one ran in this session.
  final FirmwareProgress? firmware;
  bool get updatingFirmware => firmware != null && !firmware!.finished;

  bool get heartRateLow => bpm != null && bpm! < limits.low;
  bool get heartRateHigh => bpm != null && bpm! > limits.high;

  /// True when the user should not trust the screen as live monitoring.
  bool get notMonitoring => streaming && link != LinkState.connected;

  /// A Bluetooth heart-rate sensor: it reports a sample rate of 0 and sends no ECG.
  bool get heartRateOnly => device != null && device!.sampleRate == 0;

  int? get trendMin => trend.isEmpty ? null : trend.map((p) => p.bpm).reduce((a, b) => a < b ? a : b);
  int? get trendMax => trend.isEmpty ? null : trend.map((p) => p.bpm).reduce((a, b) => a > b ? a : b);
  int? get trendAvg =>
      trend.isEmpty ? null : (trend.map((p) => p.bpm).reduce((a, b) => a + b) / trend.length).round();

  MonitorState copyWith({
    bool? sessionActive,
    LinkState? link,
    String? Function()? linkReason,
    DeviceInfo? device,
    bool? streaming,
    DateTime? Function()? recordingSince,
    int? Function()? bpm,
    HeartRateSource? hrSource,
    List<TrendPoint>? trend,
    int? ectopicBeats,
    bool? irregular,
    int? symptoms,
    int? battery,
    Set<DeviceAlarm>? alarms,
    LinkStats? stats,
    HeartRateLimits? limits,
    rec.Session? savedSession,
    FirmwareProgress? firmware,
  }) =>
      MonitorState(
        sessionActive: sessionActive ?? this.sessionActive,
        link: link ?? this.link,
        linkReason: linkReason != null ? linkReason() : this.linkReason,
        device: device ?? this.device,
        streaming: streaming ?? this.streaming,
        recordingSince: recordingSince != null ? recordingSince() : this.recordingSince,
        bpm: bpm != null ? bpm() : this.bpm,
        hrSource: hrSource ?? this.hrSource,
        trend: trend ?? this.trend,
        ectopicBeats: ectopicBeats ?? this.ectopicBeats,
        irregular: irregular ?? this.irregular,
        symptoms: symptoms ?? this.symptoms,
        battery: battery ?? this.battery,
        alarms: alarms ?? this.alarms,
        stats: stats ?? this.stats,
        limits: limits ?? this.limits,
        savedSession: savedSession ?? this.savedSession,
        firmware: firmware ?? this.firmware,
      );
}

final deviceLinkProvider = Provider<DeviceLink>((ref) => DeviceLink());

/// The in-app simulated device of the web demo; null on Android.
final demoDeviceProvider = Provider<DemoDeviceLink?>((ref) => null);

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final ecgBufferProvider = Provider<EcgBuffer>((ref) {
  final buffer = EcgBuffer();
  ref.onDispose(buffer.dispose);
  return buffer;
});

final monitorProvider = NotifierProvider<MonitorController, MonitorState>(MonitorController.new);

class MonitorController extends Notifier<MonitorState> {
  /// Heart rate is shown as unknown if no beat arrives for this long.
  static const beatTimeout = Duration(seconds: 4);
  static const trendWindow = Duration(minutes: 5);

  /// Reason the native side gives when the user ended the session.
  static const userDisconnect = 'disconnected by user';

  late DeviceLink _link;
  late EcgBuffer _ecg;
  late DateTime Function() _now;
  late SessionRecorder _recorder;
  final _rhythm = RhythmAnalyzer();
  Timer? _beatTimer;

  /// While ECG arrives, the heart rate comes from our own QRS detection, an
  /// independent check of the device (SRS-018). The device's rate is used
  /// only when no ECG has arrived for [ecgFreshness].
  static const ecgFreshness = Duration(seconds: 2);
  QrsDetector? _qrs;
  int? _lastR;
  int _qrsRestarts = 0;
  int _lastRRestart = -1;
  DateTime? _lastEcgAt;

  @override
  MonitorState build() {
    _link = ref.watch(deviceLinkProvider);
    _ecg = ref.watch(ecgBufferProvider);
    _now = ref.watch(clockProvider);
    _recorder = SessionRecorder(clock: _now);

    final subscription = _link.events.listen(_onEvent);
    ref.listen(settingsProvider, (_, next) {
      final s = next.value;
      if (s != null) state = state.copyWith(limits: HeartRateLimits(low: s.hrLow, high: s.hrHigh));
    });
    ref.onDispose(() {
      subscription.cancel();
      _beatTimer?.cancel();
    });
    _link.isStreaming().then((streaming) => state = state.copyWith(streaming: streaming));

    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    return MonitorState(limits: HeartRateLimits(low: settings.hrLow, high: settings.hrHigh));
  }

  Future<void> connect(String host, int port) async {
    state = state.copyWith(sessionActive: true);
    await _link.connect(host, port);
  }

  Future<void> connectBle(String address) async {
    state = state.copyWith(sessionActive: true);
    await _link.connectBle(address);
  }

  Future<void> disconnect() async {
    if (state.streaming) await _finishRecording();
    await _link.disconnect();
    state = state.copyWith(sessionActive: false, streaming: false, bpm: () => null);
  }

  Future<void> toggleStreaming() async {
    if (state.streaming) {
      await _link.stopStreaming();
      state = state.copyWith(streaming: false, bpm: () => null);
      await _finishRecording();
    } else {
      _ecg.clear();
      _rhythm.reset();
      final device = state.device;
      // A heart-rate-only sensor reports a sample rate of 0; the session then has no ECG.
      final rate = device != null && device.sampleRate > 0 ? device.sampleRate : 250;
      _recorder.start(sampleRate: rate, deviceId: device?.deviceId ?? 'unknown');
      await _link.startStreaming();
      state = state.copyWith(
        streaming: true,
        recordingSince: () => _recorder.startedAt,
        trend: const [],
        ectopicBeats: 0,
        irregular: false,
        symptoms: 0,
      );
    }
  }

  /// Installs [image] on the ECG device. Not while recording: the device
  /// refuses, and a recording must never be interrupted by maintenance.
  Future<void> updateFirmware(Uint8List image, String version) async {
    if (state.streaming) throw StateError('Stop the recording before updating the firmware');
    state = state.copyWith(firmware: FirmwareProgress(FirmwareStage.sending, 0, image.length));
    try {
      await _link.updateFirmware(image, version);
    } on Exception catch (e) {
      state = state.copyWith(firmware: FirmwareProgress(FirmwareStage.failed, 0, image.length, '$e'));
    }
  }

  Future<void> cancelFirmware() => _link.cancelFirmware();

  /// Patient-reported symptom, tied to the current moment of the ECG, as in a
  /// Holter diary.
  void markSymptom(String symptom) {
    if (!state.streaming) return;
    _recorder.addEvent(rec.SessionEventKind.symptom, symptom);
    state = state.copyWith(symptoms: state.symptoms + 1);
  }

  Future<void> _finishRecording() async {
    final result = _recorder.finish(ectopicBeats: _rhythm.ectopicBeats);
    state = state.copyWith(recordingSince: () => null);
    if (result == null) return;
    final (session, ecg) = result;
    await ref.read(sessionRepositoryProvider).save(session, ecg);
    ref.invalidate(sessionsProvider);
    state = state.copyWith(savedSession: session);
  }

  void _onEvent(DeviceEvent event) {
    switch (event) {
      case LinkChanged(:final state, :final reason):
        if (state != this.state.link) {
          _recorder.addEvent(rec.SessionEventKind.link, switch (state) {
            LinkState.connected => 'Device connected',
            LinkState.connecting => 'Reconnecting',
            LinkState.disconnected => 'Link lost${reason != null ? ': $reason' : ''}',
          });
        }
        this.state = this.state.copyWith(
              sessionActive: state != LinkState.disconnected || this.state.sessionActive && reason != userDisconnect,
              link: state,
              linkReason: () => reason,
              bpm: state == LinkState.connected ? null : () => null,
            );
      case DeviceInfo():
        if (event.sampleRate > 0) _ecg.setSampleRate(event.sampleRate);
        _qrs = null; // a new device may stream at another rate
        state = state.copyWith(device: event);
      case EcgChunk(:final firstIndex, :final samples):
        _ecg.addChunk(firstIndex, samples);
        _recorder.addEcg(firstIndex, samples);
        _detectBeats(firstIndex, samples);
      case HeartRateReading(:final bpm, :final rrMs):
        final ecgAt = _lastEcgAt;
        if (ecgAt == null || _now().difference(ecgAt) > ecgFreshness) _onBeat(bpm, rrMs, HeartRateSource.device);
      case BatteryLevel(:final percent):
        state = state.copyWith(battery: percent);
      case DeviceAlarmChanged(:final alarm, :final active):
        final alarms = {...state.alarms};
        active ? alarms.add(alarm) : alarms.remove(alarm);
        final name = alarm == DeviceAlarm.leadOff ? 'Electrode off' : 'Low battery';
        _recorder.addEvent(rec.SessionEventKind.alarm, active ? name : '$name cleared');
        state = state.copyWith(
          alarms: alarms,
          // No trustworthy heart rate while an electrode is off.
          bpm: alarm == DeviceAlarm.leadOff && active ? () => null : null,
        );
      case LinkStats():
        state = state.copyWith(stats: event);
      case FirmwareProgress():
        state = state.copyWith(firmware: event);
      case SamplesLost() || CommandAck():
        break; // gaps already show in the ECG buffer; acks are not needed by the UI
    }
  }

  void _detectBeats(int firstIndex, List<int> samples) {
    _lastEcgAt = _now();
    final rate = state.device?.sampleRate ?? 250;
    final qrs = _qrs ??= QrsDetector(sampleRate: rate > 0 ? rate : 250, onBeat: _onR);
    for (var i = 0; i < samples.length; i++) {
      final index = firstIndex + i;
      // A jump in the index (lost samples, restarted stream) restarts learning,
      // and the interval across it is not a real RR.
      if (i == 0 && index != (_qrsNext ?? index)) _qrsRestarts++;
      qrs.add(index, samples[i]);
    }
    _qrsNext = firstIndex + samples.length;
  }

  int? _qrsNext;

  void _onR(int index) {
    final last = _lastR;
    final rate = _qrs!.sampleRate;
    _lastR = index;
    final sameRun = _lastRRestart == _qrsRestarts;
    _lastRRestart = _qrsRestarts;
    if (!sameRun) _beatsInRun = 0;
    _beatsInRun++;
    // The first interval after learning is often a T wave taken for a beat:
    // skip it. Then keep only intervals a heart can produce (30–220 bpm).
    if (last == null || !sameRun || index <= last || _beatsInRun <= 2) return;
    final rrMs = (index - last) * 1000 ~/ rate;
    if (rrMs < minRrMs || rrMs > maxRrMs) return;
    _onBeat((60000 / rrMs).round(), rrMs, HeartRateSource.ecg);
  }

  int _beatsInRun = 0;
  static const minRrMs = 273; // 220 bpm
  static const maxRrMs = 2000; // 30 bpm

  void _onBeat(int bpm, int rrMs, HeartRateSource source) {
    _beatTimer?.cancel();
    _beatTimer = Timer(beatTimeout, () => state = state.copyWith(bpm: () => null));

    final wasOut = state.heartRateLow || state.heartRateHigh;
    final premature = _rhythm.add(rrMs);
    if (premature) _recorder.addEvent(rec.SessionEventKind.heartRate, 'Premature beat');
    _recorder.addHeartRate(bpm);

    final now = _now();
    final cutoff = now.subtract(trendWindow);
    final trend = [
      for (final p in state.trend)
        if (p.at.isAfter(cutoff)) p,
      TrendPoint(now, bpm),
    ];
    state = state.copyWith(
      bpm: () => bpm,
      hrSource: source,
      trend: trend,
      ectopicBeats: _rhythm.ectopicBeats,
      irregular: _rhythm.irregular,
    );

    final isOut = state.heartRateLow || state.heartRateHigh;
    if (isOut && !wasOut) {
      _recorder.addEvent(rec.SessionEventKind.alarm, 'Heart rate $bpm bpm outside ${state.limits.low}–${state.limits.high}');
    }
  }
}
