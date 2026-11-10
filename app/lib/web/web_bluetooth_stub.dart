import 'package:device_link/device_link.dart';

class WebBluetooth {
  bool get supported => false;

  Future<void> connect(void Function(DeviceEvent) emit) async =>
      emit(const LinkChanged(LinkState.disconnected, 'Bluetooth is not available here'));

  Future<void> disconnect() async {}
}
