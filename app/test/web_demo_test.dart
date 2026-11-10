import 'dart:io';
import 'dart:typed_data';

import 'package:device_link/device_link.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsebridge/web/demo_device.dart';
import 'package:pulsebridge/web/heart_rate_measurement.dart';

DemoRecording asset() => DemoRecording.parse(ByteData.sublistView(File('assets/demo/mitbih119.bin').readAsBytesSync()));

void main() {
  group('Demo device (web)', () {
    test('the bundled MIT-BIH excerpt is 5 minutes at 250 Hz with its beats', () {
      final r = asset();
      expect(r.sampleRate, 250);
      expect(r.samples.length, 5 * 60 * 250);
      expect(r.beatIndex.length, greaterThan(250));
      expect(r.beatRrMs.where((rr) => rr < 700), isNotEmpty, reason: 'record 119 has premature beats');
    });

    test('connects, streams 10 chunks a second and reports beats, like the simulator', () {
      fakeAsync((async) {
        final demo = DemoDeviceLink(() async => asset());
        final events = <DeviceEvent>[];
        demo.events.listen(events.add);
        demo.connect('demo', 0);
        async.elapse(const Duration(seconds: 1));
        expect(events.whereType<DeviceInfo>().single.sampleRate, 250);
        expect(events.whereType<EcgChunk>(), isEmpty, reason: 'no stream before start');

        demo.startStreaming();
        async.elapse(const Duration(seconds: 10));
        final chunks = events.whereType<EcgChunk>().toList();
        expect(chunks.length, inInclusiveRange(99, 101));
        expect(chunks[1].firstIndex, 25);
        expect(events.whereType<HeartRateReading>().length, greaterThan(5));
      });
    });

    test('a dropped link goes down, then reconnects on its own', () {
      fakeAsync((async) {
        final demo = DemoDeviceLink(() async => asset());
        final links = <LinkState>[];
        demo.events.listen((e) {
          if (e is LinkChanged) links.add(e.state);
        });
        demo.connect('demo', 0);
        async.elapse(const Duration(seconds: 1));
        demo.dropLink(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 3));
        expect(links, [
          LinkState.connecting,
          LinkState.connected,
          LinkState.disconnected,
          LinkState.connecting,
          LinkState.connected,
        ]);
      });
    });

    test('the firmware update goes through every stage and comes back with the new version', () {
      fakeAsync((async) {
        final demo = DemoDeviceLink(() async => asset());
        final events = <DeviceEvent>[];
        demo.events.listen(events.add);
        demo.connect('demo', 0);
        async.elapse(const Duration(seconds: 1));
        demo.updateFirmware(Uint8List(98304), '1.1.0');
        async.elapse(const Duration(seconds: 15));
        final stages = events.whereType<FirmwareProgress>().map((p) => p.stage).toSet();
        expect(stages, containsAll(FirmwareStage.values.where((s) => s != FirmwareStage.failed && s != FirmwareStage.cancelled)));
        expect(events.whereType<DeviceInfo>().last.firmware, '1.1.0');
      });
    });
  });

  group('Web Bluetooth translator', () {
    Uint8List bytes(List<int> v) => Uint8List.fromList(v);

    test('parses the measurement as the Bluetooth spec defines it', () {
      expect(HeartRateMeasurement.parse(bytes([0x00, 72])).bpm, 72);
      expect(HeartRateMeasurement.parse(bytes([0x01, 0x2C, 0x01])).bpm, 300);
      expect(HeartRateMeasurement.parse(bytes([0x04, 0])).contact, isFalse);
      expect(HeartRateMeasurement.parse(bytes([0x18, 70, 2, 1, 0, 4, 0, 2])).rrMs, [1000, 500]);
      expect(() => HeartRateMeasurement.parse(bytes([0x01])), throwsFormatException);
    });

    test('lost contact is electrode off, and silence is a lost link', () {
      fakeAsync((async) {
        final events = <DeviceEvent>[];
        final t = HeartRateTranslator(events.add)..connected('Polar H10');
        t.measurement(bytes([0x16, 64, 0, 4])); // contact, RR 1000 ms
        t.measurement(bytes([0x04, 0])); // contact lost
        expect(events.whereType<HeartRateReading>().single.bpm, 60);
        expect(events.whereType<DeviceAlarmChanged>().single.active, isTrue);

        async.elapse(const Duration(seconds: 6));
        expect(events.whereType<LinkChanged>().last.state, LinkState.disconnected);
        expect(events.whereType<LinkChanged>().last.reason, 'no data from sensor');
      });
    });
  });
}
