import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_link_platform_interface.dart';
import 'src/bluetooth.dart';
import 'src/events.dart';

class MethodChannelDeviceLink extends DeviceLinkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('pt.margaridapereira.device_link/methods');

  @visibleForTesting
  final eventChannel = const EventChannel('pt.margaridapereira.device_link/events');

  late final Stream<DeviceEvent> _events = eventChannel
      .receiveBroadcastStream()
      .map((e) => DeviceEvent.fromMap(e as Map<Object?, Object?>))
      .where((e) => e != null)
      .cast<DeviceEvent>();

  @override
  Stream<DeviceEvent> get events => _events;

  @override
  Future<void> connect(String host, int port) =>
      methodChannel.invokeMethod('connect', {'host': host, 'port': port});

  @override
  Future<void> updateFirmware(Uint8List image, String version) =>
      methodChannel.invokeMethod('updateFirmware', {'image': image, 'version': version});

  @override
  Future<void> cancelFirmware() => methodChannel.invokeMethod('cancelFirmware');

  @override
  Future<void> connectBle(String address) => methodChannel.invokeMethod('connectBle', {'address': address});

  @override
  Future<BluetoothState> bluetoothState() async =>
      BluetoothState.fromMap(await methodChannel.invokeMethod<Map<Object?, Object?>>('bluetoothState') ?? const {});

  @override
  Future<bool> requestBluetoothPermissions() async =>
      await methodChannel.invokeMethod<bool>('requestBluetoothPermissions') ?? false;

  @override
  Future<List<BleDevice>> scanBle(Duration duration) async {
    final list = await methodChannel.invokeListMethod<Map<Object?, Object?>>(
      'scanBle',
      {'durationMs': duration.inMilliseconds},
    );
    return [for (final m in list ?? const <Map<Object?, Object?>>[]) BleDevice.fromMap(m)];
  }

  @override
  Future<void> disconnect() => methodChannel.invokeMethod('disconnect');

  @override
  Future<void> startStreaming() => methodChannel.invokeMethod('startStreaming');

  @override
  Future<void> stopStreaming() => methodChannel.invokeMethod('stopStreaming');

  @override
  Future<bool> isStreaming() async =>
      await methodChannel.invokeMethod<bool>('isStreaming') ?? false;
}
