import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:device_link/device_link.dart';
import 'package:web/web.dart' as web;

import 'heart_rate_measurement.dart';

/// A heart-rate sensor through the browser's Web Bluetooth API (Chrome, Edge,
/// Android Chrome). The browser shows its own picker, filtered to sensors
/// with the Heart Rate Service.
class WebBluetooth {
  JSObject? get _api => web.window.navigator.getProperty<JSObject?>('bluetooth'.toJS);

  bool get supported => _api != null;

  JSObject? _device;
  HeartRateTranslator? _translator;

  Future<void> connect(void Function(DeviceEvent) emit) async {
    final api = _api;
    if (api == null) {
      emit(const LinkChanged(LinkState.disconnected, 'this browser has no Web Bluetooth'));
      return;
    }
    final translator = _translator = HeartRateTranslator(emit);
    try {
      final options = {
        'filters': [
          {
            'services': ['heart_rate'],
          },
        ],
        'optionalServices': ['battery_service'],
      }.jsify()!;
      final device = await api.callMethod<JSPromise<JSObject>>('requestDevice'.toJS, options).toDart;
      _device = device;
      device.callMethod<JSAny?>(
        'addEventListener'.toJS,
        'gattserverdisconnected'.toJS,
        ((web.Event _) => translator.lost('sensor disconnected')).toJS,
      );
      final gatt = device.getProperty<JSObject>('gatt'.toJS);
      final server = await gatt.callMethod<JSPromise<JSObject>>('connect'.toJS).toDart;
      final service =
          await server.callMethod<JSPromise<JSObject>>('getPrimaryService'.toJS, 'heart_rate'.toJS).toDart;
      final hr = await service
          .callMethod<JSPromise<JSObject>>('getCharacteristic'.toJS, 'heart_rate_measurement'.toJS)
          .toDart;
      hr.callMethod<JSAny?>(
        'addEventListener'.toJS,
        'characteristicvaluechanged'.toJS,
        ((web.Event e) {
          final view = (e.target! as JSObject).getProperty<JSDataView>('value'.toJS).toDart;
          translator.measurement(Uint8List.sublistView(view));
        }).toJS,
      );
      await hr.callMethod<JSPromise<JSAny?>>('startNotifications'.toJS).toDart;
      translator.connected(device.getProperty<JSString?>('name'.toJS)?.toDart ?? 'Heart-rate sensor');
      await _readBattery(server, translator);
    } catch (e) {
      // The user closed the picker, or the sensor refused.
      translator.lost('$e'.contains('NotFoundError') ? 'no sensor chosen' : 'Bluetooth: $e');
    }
  }

  Future<void> _readBattery(JSObject server, HeartRateTranslator translator) async {
    try {
      final service =
          await server.callMethod<JSPromise<JSObject>>('getPrimaryService'.toJS, 'battery_service'.toJS).toDart;
      final level =
          await service.callMethod<JSPromise<JSObject>>('getCharacteristic'.toJS, 'battery_level'.toJS).toDart;
      final value = await level.callMethod<JSPromise<JSDataView>>('readValue'.toJS).toDart;
      translator.battery(value.toDart.getUint8(0));
    } catch (_) {
      // Many sensors have no battery service.
    }
  }

  Future<void> disconnect() async {
    _translator?.dispose();
    final gatt = _device?.getProperty<JSObject?>('gatt'.toJS);
    gatt?.callMethod<JSAny?>('disconnect'.toJS);
    _device = null;
  }
}
