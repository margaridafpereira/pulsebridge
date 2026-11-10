import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_link_method_channel.dart';
import 'src/bluetooth.dart';
import 'src/events.dart';

abstract class DeviceLinkPlatform extends PlatformInterface {
  DeviceLinkPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceLinkPlatform _instance = MethodChannelDeviceLink();

  static DeviceLinkPlatform get instance => _instance;

  static set instance(DeviceLinkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<DeviceEvent> get events;

  Future<void> connect(String host, int port);

  Future<void> disconnect();

  Future<void> updateFirmware(Uint8List image, String version) =>
      throw UnimplementedError('Firmware update is not supported');

  Future<void> cancelFirmware() async {}

  // Bluetooth has defaults so platforms and fakes without it still work.
  Future<void> connectBle(String address) => throw UnimplementedError('Bluetooth is not supported');

  Future<BluetoothState> bluetoothState() async =>
      const BluetoothState(supported: false, enabled: false, permitted: false);

  Future<bool> requestBluetoothPermissions() async => false;

  Future<List<BleDevice>> scanBle(Duration duration) async => const [];

  Future<void> startStreaming();

  Future<void> stopStreaming();

  Future<bool> isStreaming();
}
