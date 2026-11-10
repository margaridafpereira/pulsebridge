import 'dart:async';
import 'dart:typed_data';

import 'package:device_link/device_link.dart';

/// Heart Rate Measurement (GATT 0x2A37), Bluetooth SIG Heart Rate Service 1.0
/// §3.1. The Dart twin of the Kotlin parser, for Web Bluetooth.
class HeartRateMeasurement {
  const HeartRateMeasurement(this.bpm, this.contact, this.rrMs);

  final int bpm;

  /// Null when the sensor cannot detect skin contact.
  final bool? contact;
  final List<int> rrMs;

  static HeartRateMeasurement parse(Uint8List v) {
    if (v.length < 2) throw const FormatException('heart rate measurement too short');
    final flags = v[0];
    var i = 1;
    int bpm;
    if (flags & 0x01 != 0) {
      if (v.length < 3) throw const FormatException('missing 16-bit heart rate');
      bpm = v[1] | v[2] << 8;
      i = 3;
    } else {
      bpm = v[1];
      i = 2;
    }
    final contact = flags & 0x04 != 0 ? flags & 0x02 != 0 : null;
    if (flags & 0x08 != 0) i += 2; // energy expended, not used
    final rr = <int>[];
    if (flags & 0x10 != 0) {
      for (; i + 1 < v.length; i += 2) {
        rr.add(((v[i] | v[i + 1] << 8) * 1000 + 512) ~/ 1024);
      }
    }
    return HeartRateMeasurement(bpm, contact, rr);
  }
}

/// Turns sensor notifications into app events with the same rules as the
/// Kotlin session: one beat per RR interval, lost contact = electrode off,
/// 5 s without data = link lost.
class HeartRateTranslator {
  HeartRateTranslator(this.emit, {this.silence = const Duration(seconds: 5)});

  final void Function(DeviceEvent) emit;
  final Duration silence;
  bool _contactLost = false;
  Timer? _watchdog;

  void connected(String name) {
    emit(const LinkChanged(LinkState.connected));
    emit(DeviceInfo(name, '', 0));
    _arm();
  }

  void measurement(Uint8List value) {
    _arm();
    final HeartRateMeasurement m;
    try {
      m = HeartRateMeasurement.parse(value);
    } on FormatException {
      return; // malformed notification: dropped, like a bad frame
    }
    final lost = m.contact == false;
    if (lost != _contactLost) {
      _contactLost = lost;
      emit(DeviceAlarmChanged(DeviceAlarm.leadOff, lost));
    }
    if (lost || m.bpm == 0) return;
    if (m.rrMs.isEmpty) {
      emit(HeartRateReading(m.bpm, 60000 ~/ m.bpm));
    } else {
      for (final rr in m.rrMs) {
        if (rr > 0) emit(HeartRateReading((60000 / rr).round(), rr));
      }
    }
  }

  void battery(int percent) => emit(BatteryLevel(percent));

  void lost(String reason) {
    _watchdog?.cancel();
    if (_contactLost) {
      _contactLost = false;
      emit(const DeviceAlarmChanged(DeviceAlarm.leadOff, false));
    }
    emit(LinkChanged(LinkState.disconnected, reason));
  }

  void dispose() => _watchdog?.cancel();

  void _arm() {
    _watchdog?.cancel();
    _watchdog = Timer(silence, () => lost('no data from sensor'));
  }
}
