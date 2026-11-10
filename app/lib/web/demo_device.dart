import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_link/device_link.dart';
import 'package:device_link/device_link_platform_interface.dart';

import 'web_bluetooth.dart';

/// A recorded ECG to play back: samples in µV and the annotated beats.
class DemoRecording {
  DemoRecording(this.sampleRate, this.samples, this.beatIndex, this.beatRrMs);

  final int sampleRate;
  final Int16List samples;
  final Uint32List beatIndex;
  final Uint16List beatRrMs;

  /// Reads the asset written by `python -m pulsebridge_sim.demo_asset`.
  factory DemoRecording.parse(ByteData data) {
    var o = 0;
    int u32() => data.getUint32((o += 4) - 4, Endian.little);
    final rate = u32();
    final n = u32();
    final samples = Int16List(n);
    for (var i = 0; i < n; i++) {
      samples[i] = data.getInt16(o + i * 2, Endian.little);
    }
    o += n * 2;
    final beats = u32();
    final index = Uint32List(beats), rr = Uint16List(beats);
    for (var i = 0; i < beats; i++) {
      index[i] = data.getUint32(o, Endian.little);
      rr[i] = data.getUint16(o + 4, Endian.little);
      o += 6;
    }
    return DemoRecording(rate, samples, index, rr);
  }
}

/// The ECG device, simulated inside the app, for the web build where there is
/// no TCP socket and no Kotlin. It behaves like the Python simulator: HELLO
/// and battery on connect, streaming only when started, a looping MIT-BIH
/// recording, faults on demand and a firmware update with a link drop.
///
/// Bluetooth heart-rate sensors go through Web Bluetooth when the browser
/// has it (Chrome, Edge).
class DemoDeviceLink extends DeviceLinkPlatform {
  DemoDeviceLink(this._load, {WebBluetooth? bluetooth}) : _bluetooth = bluetooth ?? WebBluetooth();

  final Future<DemoRecording> Function() _load;
  final WebBluetooth _bluetooth;
  final _events = StreamController<DeviceEvent>.broadcast();

  DemoRecording? _recording;
  LinkState _link = LinkState.disconnected;
  bool _streaming = false;
  bool _usingBluetooth = false;
  String _firmware = '1.0.0';
  double _battery = 100;
  Timer? _ticker;
  int _position = 0; // sample within the recording
  int _index = 0; // sample index sent to the app since streaming started
  int _nextBeat = 0;
  bool _leadOff = false;

  static const chunk = 25; // 100 ms at 250 Hz, like the simulator's 10 frames per second

  @override
  Stream<DeviceEvent> get events => _events.stream;

  void _emit(DeviceEvent e) => _events.add(e);

  @override
  Future<void> connect(String host, int port) async {
    _usingBluetooth = false;
    _recording ??= await _load();
    _setLink(LinkState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _hello();
  }

  void _hello() {
    _setLink(LinkState.connected);
    _emit(DeviceInfo('PB-DEMO-0001', _firmware, _recording!.sampleRate));
    _emit(BatteryLevel(_battery.round()));
    if (_streaming) _startTicker();
  }

  void _setLink(LinkState state, [String? reason]) {
    _link = state;
    _emit(LinkChanged(state, reason));
  }

  @override
  Future<void> disconnect() async {
    _ticker?.cancel();
    _streaming = false;
    if (_usingBluetooth) await _bluetooth.disconnect();
    _setLink(LinkState.disconnected, 'disconnected by user');
  }

  @override
  Future<void> startStreaming() async {
    if (_usingBluetooth) {
      _streaming = true;
      return;
    }
    _streaming = true;
    _index = 0;
    _emit(const CommandAck(1, 'OK'));
    if (_link == LinkState.connected) _startTicker();
  }

  @override
  Future<void> stopStreaming() async {
    _streaming = false;
    _ticker?.cancel();
  }

  @override
  Future<bool> isStreaming() async => _streaming;

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    final r = _recording!;
    final out = Int32List(chunk);
    for (var i = 0; i < chunk; i++) {
      // Electrode off: the trace goes flat with noise, as a real lead does.
      out[i] = _leadOff ? Random().nextInt(60) - 30 : r.samples[(_position + i) % r.samples.length];
    }
    _emit(EcgChunk(_index, out));
    final end = _position + chunk;
    while (_nextBeat < r.beatIndex.length && r.beatIndex[_nextBeat] < end) {
      final rr = r.beatRrMs[_nextBeat];
      if (!_leadOff && rr > 0) _emit(HeartRateReading((60000 / rr).round().clamp(1, 255), rr));
      _nextBeat++;
    }
    _position = end;
    if (_position >= r.samples.length) {
      _position -= r.samples.length;
      _nextBeat = 0;
    }
    _index += chunk;
    final before = _battery.round();
    _battery = max(0, _battery - 0.5 / 600); // 0.5 % per minute while streaming
    if (_battery.round() != before) _emit(BatteryLevel(_battery.round()));
  }

  /// Demo control: the link drops and comes back, so NOT MONITORING and the
  /// automatic reconnect can be seen.
  Future<void> dropLink(Duration duration) async {
    if (_link != LinkState.connected || _usingBluetooth) return;
    _ticker?.cancel();
    _setLink(LinkState.disconnected, 'no data from device');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _setLink(LinkState.connecting);
    await Future<void>.delayed(duration);
    _hello();
  }

  /// Demo control: an electrode comes off for a while.
  Future<void> electrodeOff(Duration duration) async {
    if (_link != LinkState.connected || _usingBluetooth) return;
    _leadOff = true;
    _emit(const DeviceAlarmChanged(DeviceAlarm.leadOff, true));
    await Future<void>.delayed(duration);
    _leadOff = false;
    _emit(const DeviceAlarmChanged(DeviceAlarm.leadOff, false));
  }

  /// The same stages as the real update, timed, with a link drop at 40 % so
  /// the resume shows. The real protocol runs against the Python simulator.
  @override
  Future<void> updateFirmware(Uint8List image, String version) async {
    if (_usingBluetooth || _link != LinkState.connected) throw StateError('connect to the ECG device first');
    if (_streaming) throw StateError('stop the recording first');
    final total = image.length;
    for (var sent = 0; sent <= total; sent += total ~/ 50) {
      if (sent >= total * 0.4 && sent < total * 0.4 + total ~/ 50) {
        _emit(FirmwareProgress(FirmwareStage.waitingForLink, sent, total, 'link lost, will resume'));
        _setLink(LinkState.disconnected, 'link lost');
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        _setLink(LinkState.connected);
        _emit(FirmwareProgress(FirmwareStage.sending, sent, total, 'resuming'));
      }
      _emit(FirmwareProgress(FirmwareStage.sending, sent, total));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    _emit(FirmwareProgress(FirmwareStage.verifying, total, total, 'checking the image'));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _emit(FirmwareProgress(FirmwareStage.restarting, total, total, 'installed $version, restarting'));
    _setLink(LinkState.connecting, 'device restarting');
    await Future<void>.delayed(const Duration(seconds: 2));
    _firmware = version;
    _hello();
    _emit(FirmwareProgress(FirmwareStage.done, total, total, 'running $version'));
  }

  // Bluetooth through the browser.

  @override
  Future<BluetoothState> bluetoothState() async =>
      BluetoothState(supported: _bluetooth.supported, enabled: _bluetooth.supported, permitted: true);

  @override
  Future<bool> requestBluetoothPermissions() async => _bluetooth.supported;

  /// The browser shows its own sensor picker, so there is nothing to list.
  @override
  Future<List<BleDevice>> scanBle(Duration duration) async => const [];

  @override
  Future<void> connectBle(String address) async {
    _ticker?.cancel();
    _usingBluetooth = true;
    _setLink(LinkState.connecting);
    await _bluetooth.connect(_emit);
  }
}
