import 'dart:async';
import 'dart:typed_data';

import 'package:device_link/device_link.dart';
import 'package:device_link/device_link_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pulsebridge/l10n/app_localizations.dart';
import 'package:pulsebridge/monitor/ecg_buffer.dart';
import 'package:pulsebridge/monitor/monitor_controller.dart';
import 'package:pulsebridge/monitor/monitor_screen.dart';
import 'package:pulsebridge/monitor/rhythm.dart';
import 'package:pulsebridge/profile/profile.dart';
import 'package:pulsebridge/sessions/session.dart' as rec;
import 'package:pulsebridge/sessions/session_recorder.dart';
import 'package:pulsebridge/sessions/session_repository.dart';
import 'package:pulsebridge/sessions/sessions_provider.dart';
import 'package:pulsebridge/settings/settings.dart';

class FakePlatform extends DeviceLinkPlatform with MockPlatformInterfaceMixin {
  final controller = StreamController<DeviceEvent>.broadcast();
  final calls = <String>[];

  void emit(DeviceEvent event) => controller.add(event);

  @override
  Stream<DeviceEvent> get events => controller.stream;
  @override
  Future<void> connect(String host, int port) async => calls.add('connect $host:$port');
  @override
  Future<void> disconnect() async => calls.add('disconnect');
  @override
  Future<void> startStreaming() async => calls.add('start');
  @override
  Future<void> stopStreaming() async => calls.add('stop');
  @override
  Future<bool> isStreaming() async => false;
}

void main() {
  group('EcgBuffer', () {
    test('wraps around the window', () {
      final buffer = EcgBuffer(windowSeconds: 1, sampleRate: 10, filter: false);
      buffer.addChunk(0, List.generate(12, (i) => i));
      expect(buffer.cursor, 2);
      expect(buffer.valueAt(0), 10);
      expect(buffer.valueAt(1), 11);
      expect(buffer.valueAt(2), 2);
    });

    test('marks lost samples as a gap instead of drawing through them', () {
      final buffer = EcgBuffer(windowSeconds: 1, sampleRate: 10, filter: false);
      buffer.addChunk(0, [1, 2]);
      buffer.addChunk(5, [6]);
      expect([for (var i = 0; i < 6; i++) buffer.valueAt(i)],
          [1, 2, EcgBuffer.gap, EcgBuffer.gap, EcgBuffer.gap, 6]);
    });

    test('a restarted stream starts writing from its own index', () {
      final buffer = EcgBuffer(windowSeconds: 1, sampleRate: 10, filter: false);
      buffer.addChunk(0, List.filled(7, 1));
      buffer.addChunk(0, [9]);
      expect(buffer.valueAt(0), 9);
      expect(buffer.cursor, 1);
    });

    test('high-pass filter removes a constant baseline offset', () {
      final buffer = EcgBuffer(windowSeconds: 4, sampleRate: 250);
      buffer.addChunk(0, List.filled(1000, -800)); // -0.8 mV offset
      expect(buffer.valueAt(999).abs(), lessThan(20));
    });
  });

  group('RhythmAnalyzer', () {
    test('regular sinus rhythm has no premature beats and is regular', () {
      final rhythm = RhythmAnalyzer();
      for (var i = 0; i < 30; i++) {
        rhythm.add(830 + (i.isEven ? 10 : -10));
      }
      expect(rhythm.ectopicBeats, 0);
      expect(rhythm.irregular, isFalse);
    });

    test('a short RR followed by a compensatory pause counts as premature', () {
      final rhythm = RhythmAnalyzer();
      for (var i = 0; i < 10; i++) {
        rhythm.add(900);
      }
      expect(rhythm.add(540), isTrue);
      expect(rhythm.add(1300), isFalse);
      expect(rhythm.ectopicBeats, 1);
    });

    test('random RR intervals are flagged irregular', () {
      final rhythm = RhythmAnalyzer();
      const rr = [620, 910, 540, 1010, 700, 480, 880, 760, 1050, 590];
      for (var i = 0; i < 25; i++) {
        rhythm.add(rr[i % rr.length]);
      }
      expect(rhythm.irregular, isTrue);
    });
  });

  group('Sessions', () {
    test('recorder keeps gaps and the repository round-trips through the store', () async {
      var now = DateTime(2026, 11, 9, 10);
      final recorder = SessionRecorder(clock: () => now)..start(sampleRate: 250, deviceId: 'PB-1');
      recorder.addEcg(0, [100, 200]);
      recorder.addEcg(4, [300]); // samples 2 and 3 lost
      recorder.addHeartRate(72);
      now = now.add(const Duration(seconds: 30));
      recorder.addEvent(rec.SessionEventKind.symptom, 'Palpitations');
      final (session, ecg) = recorder.finish(ectopicBeats: 2)!;

      final repo = SessionRepository(MemoryBlobStore());
      await repo.save(session, ecg);
      final loaded = (await repo.list()).single;
      expect(loaded.duration, const Duration(seconds: 30));
      expect(loaded.lostSamples, 2);
      expect(loaded.symptomCount, 1);
      expect(loaded.events.firstWhere((e) => e.kind == rec.SessionEventKind.symptom).atMs, 30000);

      final signal = await repo.loadEcg(loaded);
      expect(signal!.samples, [100, 200, rec.SessionEcg.gap, rec.SessionEcg.gap, 300]);
    });

    test('an empty recording is not saved', () {
      final recorder = SessionRecorder()..start(sampleRate: 250, deviceId: 'PB-1');
      expect(recorder.finish(ectopicBeats: 0), isNull);
    });
  });

  group('PatientProfile', () {
    test('predicts maximum heart rate from age', () {
      const profile = PatientProfile(name: 'Ana Silva', birthYear: 1996);
      expect(profile.age(DateTime(2026)), 30);
      expect(profile.predictedMaxHr(DateTime(2026)), 187);
      expect(profile.initials, 'AS');
    });
  });

  group('MonitorController', () {
    late FakePlatform platform;
    late MemoryBlobStore store;
    late ProviderContainer container;

    setUp(() {
      platform = FakePlatform();
      store = MemoryBlobStore();
      container = ProviderContainer(overrides: [
        deviceLinkProvider.overrideWithValue(DeviceLink(platform)),
        blobStoreProvider.overrideWithValue(store),
      ]);
      container.listen(monitorProvider, (_, _) {});
    });

    tearDown(() => container.dispose());

    MonitorState state() => container.read(monitorProvider);
    MonitorController controller() => container.read(monitorProvider.notifier);

    test('shows heart rate and drops it when an electrode comes off', () async {
      platform.emit(const LinkChanged(LinkState.connected));
      platform.emit(const HeartRateReading(72, 833));
      await pumpEventQueue();
      expect(state().bpm, 72);
      expect(state().trend, hasLength(1));

      platform.emit(const DeviceAlarmChanged(DeviceAlarm.leadOff, true));
      await pumpEventQueue();
      expect(state().bpm, isNull);
      expect(state().alarms, contains(DeviceAlarm.leadOff));
    });

    test('flags heart rate outside the limits', () async {
      platform.emit(const HeartRateReading(150, 400));
      await pumpEventQueue();
      expect(state().heartRateHigh, isTrue);
    });

    test('link loss while recording means not monitoring', () async {
      await controller().connect('10.0.2.2', 7878);
      platform.emit(const LinkChanged(LinkState.connected));
      await pumpEventQueue();
      await controller().toggleStreaming();
      expect(state().notMonitoring, isFalse);

      platform.emit(const LinkChanged(LinkState.disconnected, 'no data from device'));
      await pumpEventQueue();
      expect(state().notMonitoring, isTrue);
      expect(state().sessionActive, isTrue, reason: 'still reconnecting');
    });

    test('a recording with a symptom is saved encrypted when stopped', () async {
      platform.emit(const LinkChanged(LinkState.connected));
      platform.emit(const DeviceInfo('PB-SIM-0001', '1.0.0', 250));
      await pumpEventQueue();
      await controller().toggleStreaming();
      platform.emit(EcgChunk(0, Int32List.fromList(List.filled(25, 100))));
      platform.emit(const HeartRateReading(70, 857));
      await pumpEventQueue();
      controller().markSymptom('Palpitations');
      await controller().toggleStreaming();

      final sessions = await container.read(sessionsProvider.future);
      expect(sessions.single.symptomCount, 1);
      expect(sessions.single.deviceId, 'PB-SIM-0001');
      expect(store.files.keys, containsAll([startsWith('session_')]));
      expect(state().savedSession, isNotNull);
    });

    test('ECG samples go to the buffer', () async {
      platform.emit(EcgChunk(0, Int32List.fromList([100, 200])));
      await pumpEventQueue();
      expect(container.read(ecgBufferProvider).hasData, isTrue);
    });
  });

  testWidgets('shows the not-monitoring banner when the link drops during recording', (tester) async {
    // A phone-sized screen (1080 × 2400 px) so the whole monitor fits.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final platform = FakePlatform();
    final container = ProviderContainer(overrides: [
      deviceLinkProvider.overrideWithValue(DeviceLink(platform)),
      blobStoreProvider.overrideWithValue(MemoryBlobStore()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MonitorScreen(),
      ),
    ));
    await container.read(monitorProvider.notifier).connect('10.0.2.2', 7878);
    expect(platform.calls, ['connect 10.0.2.2:7878']);

    platform.emit(const LinkChanged(LinkState.connected));
    await tester.pump(const Duration(milliseconds: 500)); // the live dot pulses forever, so no pumpAndSettle
    await tester.tap(find.text('Start recording'));
    await tester.pump();

    platform.emit(const LinkChanged(LinkState.connecting));
    await tester.pump();
    expect(find.text('NOT MONITORING'), findsOneWidget);
  });
}
