import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_link/device_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsebridge/fhir/fhir_export.dart';
import 'package:pulsebridge/monitor/monitor_controller.dart';
import 'package:pulsebridge/monitor/qrs_detector.dart';
import 'package:pulsebridge/profile/profile.dart';
import 'package:pulsebridge/sessions/session.dart';
import 'package:pulsebridge/sessions/session_recorder.dart';
import 'package:pulsebridge/sessions/session_repository.dart';
import 'package:pulsebridge/settings/settings.dart';

import 'widget_test.dart' show FakePlatform;

/// Synthetic ECG: a narrow R wave every [rrMs], small noise.
List<int> syntheticEcg({required int seconds, required int rrMs, int rate = 250}) {
  final rng = Random(1);
  final rrSamples = rrMs * rate ~/ 1000;
  return [
    for (var i = 0; i < seconds * rate; i++)
      (1200 * exp(-pow(((i % rrSamples) - 20) / 3.0, 2)) + rng.nextInt(40) - 20).round(),
  ];
}

Session sampleSession() => Session(
      id: '1762684200000',
      start: DateTime(2026, 11, 9, 10, 30),
      duration: const Duration(seconds: 4),
      sampleRate: 250,
      deviceId: 'PB-SIM-0001',
      heartRate: const [HeartRatePoint(500, 70), HeartRatePoint(1400, 72), HeartRatePoint(3100, 75)],
      events: const [
        SessionEvent(0, SessionEventKind.info, 'Recording started'),
        SessionEvent(2000, SessionEventKind.symptom, 'Palpitations'),
        SessionEvent(3000, SessionEventKind.symptom, 'Exercise'),
      ],
      ectopicBeats: 3,
      lostSamples: 2,
      totalSamples: 1000,
    );

void main() {
  group('QrsDetector', () {
    test('finds every beat of a regular rhythm at the right rate', () {
      final beats = <int>[];
      final detector = QrsDetector(sampleRate: 250, onBeat: beats.add);
      final ecg = syntheticEcg(seconds: 20, rrMs: 800);
      for (var i = 0; i < ecg.length; i++) {
        detector.add(i, ecg[i]);
      }
      final afterLearning = beats.where((b) => b > 3 * 250).toList();
      expect(afterLearning.length, inInclusiveRange(20, 22)); // 17 s at 75 bpm
      for (var i = 1; i < afterLearning.length; i++) {
        expect(afterLearning[i] - afterLearning[i - 1], closeTo(200, 2));
      }
    });

    test('restarts learning after lost samples instead of bridging them', () {
      final beats = <int>[];
      final detector = QrsDetector(sampleRate: 250, onBeat: beats.add);
      final ecg = syntheticEcg(seconds: 10, rrMs: 800);
      for (var i = 0; i < ecg.length; i++) {
        detector.add(i, ecg[i]);
      }
      final before = beats.length;
      // 1 s lost: the next sample arrives with a jump in its index.
      for (var i = 0; i < ecg.length; i++) {
        detector.add(ecg.length + 250 + i, ecg[i]);
      }
      final after = beats.sublist(before);
      expect(after, isNotEmpty);
      expect(after.first, greaterThan(ecg.length + 250 + 2 * 250), reason: 'learns for 2 s first');
    });
  });

  group('Heart-rate source', () {
    late FakePlatform platform;
    late ProviderContainer container;
    var now = DateTime(2026, 11, 9, 10);

    setUp(() {
      platform = FakePlatform();
      now = DateTime(2026, 11, 9, 10);
      container = ProviderContainer(overrides: [
        deviceLinkProvider.overrideWithValue(DeviceLink(platform)),
        blobStoreProvider.overrideWithValue(MemoryBlobStore()),
        clockProvider.overrideWithValue(() => now),
      ]);
      container.listen(monitorProvider, (_, _) {});
    });
    tearDown(() => container.dispose());

    test('with ECG arriving, the rate comes from our own QRS detection', () async {
      platform.emit(const LinkChanged(LinkState.connected));
      platform.emit(const DeviceInfo('PB-SIM-0001', '1.0.0', 250));
      final ecg = syntheticEcg(seconds: 8, rrMs: 750);
      for (var i = 0; i < ecg.length; i += 25) {
        platform.emit(EcgChunk(i, Int32List.fromList(ecg.sublist(i, i + 25))));
      }
      platform.emit(const HeartRateReading(120, 500)); // a device value that disagrees
      await pumpEventQueue();

      final state = container.read(monitorProvider);
      expect(state.hrSource, HeartRateSource.ecg);
      expect(state.bpm, 80);
    });

    test('without ECG (a Bluetooth sensor), the device rate is used', () async {
      platform.emit(const LinkChanged(LinkState.connected));
      platform.emit(const DeviceInfo('Polar H10', '3.1', 0));
      platform.emit(const HeartRateReading(64, 937));
      await pumpEventQueue();
      final state = container.read(monitorProvider);
      expect(state.heartRateOnly, isTrue);
      expect(state.hrSource, HeartRateSource.device);
      expect(state.bpm, 64);
    });
  });

  group('Bluetooth settings and recordings', () {
    test('the connection type and sensor survive a save', () {
      const s = AppSettings(
        connection: DeviceConnectionKind.bluetooth,
        bleAddress: 'AA:BB:CC:DD:EE:FF',
        bleName: 'Polar H10',
        fhirServer: 'https://fhir.example.org/r4',
      );
      final back = AppSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back.connection, DeviceConnectionKind.bluetooth);
      expect(back.bleName, 'Polar H10');
      expect(back.fhirServer, 'https://fhir.example.org/r4');
      expect(AppSettings.fromJson(const {}).connection, DeviceConnectionKind.simulator);
    });

    test('a heart-rate-only recording is kept', () {
      final recorder = SessionRecorder()..start(sampleRate: 250, deviceId: 'Polar H10');
      recorder.addHeartRate(64);
      final result = recorder.finish(ectopicBeats: 0);
      expect(result, isNotNull);
      expect(result!.$2, isEmpty, reason: 'no ECG bytes');
    });
  });

  group('FHIR export', () {
    late Map<String, Object?> bundle;
    late List<Map<String, Object?>> resources;

    setUp(() {
      final samples = Int16List.fromList(List.generate(1000, (i) => i == 10 || i == 11 ? SessionEcg.gap : i % 50));
      bundle = FhirExport(random: Random(7)).bundle(
        session: sampleSession(),
        ecg: SessionEcg(samples, 250),
        profile: const PatientProfile(name: 'Ana Maria Silva', birthYear: 1990, sex: 'Female'),
        generatedAt: DateTime(2026, 11, 9, 12),
      );
      resources = [
        for (final e in bundle['entry']! as List) ((e as Map)['resource'] as Map).cast<String, Object?>(),
      ];
    });

    Map<String, Object?> byCode(String code) => resources.firstWhere(
          (r) => jsonEncode(r['code'] ?? '').contains('"$code"') && r['resourceType'] == 'Observation',
        );

    test('is a transaction bundle whose references all resolve inside it', () {
      expect(bundle['resourceType'], 'Bundle');
      expect(bundle['type'], 'transaction');
      final urls = {for (final e in bundle['entry']! as List) (e as Map)['fullUrl']};
      final refs = RegExp(r'"reference":"([^"]+)"').allMatches(jsonEncode(bundle)).map((m) => m.group(1));
      expect(refs, isNotEmpty);
      expect(urls, containsAll(refs.toSet()));
      for (final e in bundle['entry']! as List) {
        expect((e as Map)['request'], {'method': 'POST', 'url': (e['resource'] as Map)['resourceType']});
        expect(e['fullUrl'], matches(RegExp(r'^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      }
    });

    test('maps the patient', () {
      final patient = resources.firstWhere((r) => r['resourceType'] == 'Patient');
      expect(patient['name'], [
        {'text': 'Ana Maria Silva', 'family': 'Silva', 'given': ['Ana', 'Maria']},
      ]);
      expect(patient['gender'], 'female');
      expect(patient['birthDate'], '1990');
    });

    test('heart rate follows the vital-signs profile with LOINC 8867-4 and UCUM /min', () {
      final hr = resources.firstWhere((r) => r['valueQuantity'] != null && jsonEncode(r['code']).contains('8867-4'));
      expect((hr['meta']! as Map)['profile'], ['http://hl7.org/fhir/StructureDefinition/heartrate']);
      expect(hr['valueQuantity'], {'value': 72, 'unit': 'beats/minute', 'system': ucum, 'code': '/min'});
      final series = resources.firstWhere((r) => r['valueSampledData'] != null);
      expect((series['valueSampledData']! as Map)['data'], '70 72 72 75');
    });

    test('the ECG is lead II in µV, with lost samples as E', () {
      final ecg = byCode('11524-6');
      final component = (ecg['component']! as List).single as Map;
      expect(jsonEncode(component['code']), contains('131330'));
      final data = component['valueSampledData'] as Map;
      expect(data['period'], 4.0);
      expect((data['origin'] as Map)['code'], 'uV');
      final values = (data['data'] as String).split(' ');
      expect(values.length, 1000);
      expect(values.sublist(9, 13), ['9', 'E', 'E', '12']);
    });

    test('symptoms are coded in SNOMED CT when known, text otherwise', () {
      final symptoms = resources.where((r) => jsonEncode(r['code'] ?? '').contains('75325-1')).toList();
      expect(symptoms, hasLength(2));
      expect(jsonEncode(symptoms[0]['valueCodeableConcept']), contains('80313002'));
      expect(symptoms[0]['effectiveDateTime'], startsWith('2026-11-09T10:30:02'));
      expect(symptoms[1]['valueCodeableConcept'], {'text': 'Exercise'});
    });

    test('a diagnostic report lists every result', () {
      final report = resources.firstWhere((r) => r['resourceType'] == 'DiagnosticReport');
      final observations = resources.where((r) => r['resourceType'] == 'Observation').length;
      expect((report['result']! as List), hasLength(observations));
      expect(report['conclusion'], contains('not a diagnosis'));
    });

    test('dates carry a UTC offset', () {
      expect(fhirDateTime(DateTime.utc(2026, 11, 9, 10, 30)), '2026-11-09T10:30:00+00:00');
    });

    test('sending refuses plain http', () async {
      final result = await sendBundle(Uri.parse('http://fhir.example.org/r4'), bundle);
      expect(result.ok, isFalse);
      expect(result.error, contains('https'));
    });

    test('sending posts the bundle and reads the created locations', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<(String?, Map<String, Object?>)>();
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, Object?>;
        received.complete((request.headers.contentType?.mimeType, body));
        request.response
          ..headers.contentType = ContentType('application', 'fhir+json')
          ..write(jsonEncode({
            'resourceType': 'Bundle',
            'type': 'transaction-response',
            'entry': [
              {
                'response': {'status': '201 Created', 'location': 'Patient/1/_history/1'},
              },
              {
                'response': {'status': '201 Created', 'location': 'Observation/2/_history/1'},
              },
            ],
          }));
        await request.response.close();
      });

      final result = await sendBundle(Uri.parse('http://localhost:${server.port}/fhir'), bundle);
      final (type, body) = await received.future;
      expect(type, 'application/fhir+json');
      expect(body['type'], 'transaction');
      expect(result.ok, isTrue);
      expect(result.created, ['Patient/1/_history/1', 'Observation/2/_history/1']);
    });
  });
}
