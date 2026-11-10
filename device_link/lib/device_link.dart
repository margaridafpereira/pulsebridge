/// Link to a PulseBridge ECG device. The connection, protocol decoding and
/// background recording run natively (Kotlin) in a foreground service.
library;

import 'dart:typed_data';

import 'device_link_platform_interface.dart';
import 'src/bluetooth.dart';
import 'src/events.dart';

export 'secure_store.dart';
export 'src/bluetooth.dart';
export 'src/events.dart';

class DeviceLink {
  DeviceLink([DeviceLinkPlatform? platform]) : _platform = platform ?? DeviceLinkPlatform.instance;

  final DeviceLinkPlatform _platform;

  /// Device events. On listen, the last known link state, device info and
  /// battery level are replayed first.
  Stream<DeviceEvent> get events => _platform.events;

  /// Starts the foreground service and connects, reconnecting automatically
  /// until [disconnect] is called.
  Future<void> connect(String host, int port) => _platform.connect(host, port);

  /// Connects to a standard Bluetooth LE heart-rate sensor (Heart Rate Service).
  /// It sends heart rate and RR intervals but no ECG.
  Future<void> connectBle(String address) => _platform.connectBle(address);

  Future<BluetoothState> bluetoothState() => _platform.bluetoothState();

  /// Asks for the scan and connect permissions. Returns whether they are granted.
  Future<bool> requestBluetoothPermissions() => _platform.requestBluetoothPermissions();

  /// Scans for [duration] and returns what was found, heart-rate sensors first.
  Future<List<BleDevice>> scanBle({Duration duration = const Duration(seconds: 6)}) =>
      _platform.scanBle(duration);

  Future<void> disconnect() => _platform.disconnect();

  /// Sends [image] to the connected ECG device as firmware [version]. Progress
  /// arrives as [FirmwareProgress] events. Throws if the update cannot start
  /// (not connected, recording, already updating).
  Future<void> updateFirmware(Uint8List image, String version) => _platform.updateFirmware(image, version);

  Future<void> cancelFirmware() => _platform.cancelFirmware();

  Future<void> startStreaming() => _platform.startStreaming();

  Future<void> stopStreaming() => _platform.stopStreaming();

  Future<bool> isStreaming() => _platform.isStreaming();
}
