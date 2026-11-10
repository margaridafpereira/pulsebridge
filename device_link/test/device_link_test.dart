import 'dart:typed_data';

import 'package:device_link/device_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceEvent.fromMap', () {
    test('decodes ECG chunks', () {
      final event = DeviceEvent.fromMap({
        'type': 'ecg',
        'firstIndex': 250,
        'samples': Int32List.fromList([0, -150, 1200]),
      });
      expect(event, isA<EcgChunk>());
      final chunk = event! as EcgChunk;
      expect(chunk.firstIndex, 250);
      expect(chunk.samples, [0, -150, 1200]);
    });

    test('decodes link state with reason', () {
      final event = DeviceEvent.fromMap({'type': 'link', 'state': 'disconnected', 'reason': 'no data from device'})
          as LinkChanged;
      expect(event.state, LinkState.disconnected);
      expect(event.reason, 'no data from device');
    });

    test('decodes alarms', () {
      final event = DeviceEvent.fromMap({'type': 'alarm', 'code': 'LEAD_OFF', 'active': true}) as DeviceAlarmChanged;
      expect(event.alarm, DeviceAlarm.leadOff);
      expect(event.active, isTrue);
    });

    test('ignores unknown event types', () {
      expect(DeviceEvent.fromMap({'type': 'from-the-future'}), isNull);
    });
  });
}
