import 'dart:typed_data';

import 'package:device_link/device_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsebridge/firmware/firmware_screen.dart';
import 'package:pulsebridge/l10n/app_localizations.dart';
import 'package:pulsebridge/l10n/display.dart';
import 'package:pulsebridge/monitor/monitor_controller.dart';
import 'package:pulsebridge/monitor/monitor_screen.dart';
import 'package:pulsebridge/sessions/session.dart';
import 'package:pulsebridge/sessions/session_repository.dart';
import 'package:pulsebridge/settings/settings.dart';
import 'package:pulsebridge/settings/settings_screen.dart';
import 'package:pulsebridge/theme.dart';

import 'widget_test.dart' show FakePlatform;

/// Puts [screen] in a phone-sized app with a connected, recording device.
Future<(ProviderContainer, FakePlatform)> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
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
    child: MaterialApp(
      theme: buildTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen,
    ),
  ));
  return (container, platform);
}

Future<void> liveRecording(WidgetTester tester, ProviderContainer container, FakePlatform platform) async {
  await container.read(monitorProvider.notifier).connect('10.0.2.2', 7878);
  platform.emit(const LinkChanged(LinkState.connected));
  platform.emit(const DeviceInfo('PB-SIM-0001', '1.0.0', 250));
  platform.emit(const BatteryLevel(80));
  await tester.pump(const Duration(milliseconds: 100));
  await container.read(monitorProvider.notifier).toggleStreaming();
  platform.emit(const HeartRateReading(72, 833));
  platform.emit(const DeviceAlarmChanged(DeviceAlarm.lowBattery, true));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Unmounts the screen and lets the controller's beat timeout run out.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('Portuguese', () {
    testWidgets('the monitor speaks Portuguese', (tester) async {
      final (container, platform) = await pumpScreen(tester, const MonitorScreen(), locale: const Locale('pt'));
      await liveRecording(tester, container, platform);
      expect(find.text('RITMO CARDÍACO'), findsOneWidget);
      expect(find.text('Parar gravação'), findsOneWidget);
      expect(find.text('Bateria do aparelho fraca'), findsOneWidget);

      platform.emit(const LinkChanged(LinkState.connecting));
      await tester.pump();
      expect(find.text('SEM MONITORIZAÇÃO'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('plurals follow the language', (tester) async {
      final pt = lookupAppLocalizations(const Locale('pt'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.prematureBeats(1), '1 premature beat');
      expect(en.prematureBeats(3), '3 premature beats');
      expect(pt.prematureBeats(1), '1 batimento prematuro');
      // intl puts 0 in Portuguese's "one" group: zero must still read as plural.
      expect(pt.prematureBeats(0), '0 batimentos prematuros');
      expect(pt.alarmsCount(0), '0 alarmes');
      expect(pt.wrongPinAttempts(4), 'PIN errado · 4 tentativas antes de uma pausa');
    });

    test('stored English event texts are shown translated', () {
      final pt = lookupAppLocalizations(const Locale('pt'));
      expect(eventText(pt, const SessionEvent(0, SessionEventKind.link, 'Link lost: no data from device')),
          'Ligação perdida: no data from device');
      expect(eventText(pt, const SessionEvent(0, SessionEventKind.alarm, 'Heart rate 150 bpm outside 40–130')),
          'Ritmo cardíaco 150 bpm fora de 40–130');
      expect(eventText(pt, const SessionEvent(0, SessionEventKind.symptom, 'Palpitations')), 'Palpitações');
      expect(eventText(pt, const SessionEvent(0, SessionEventKind.info, 'Something new')), 'Something new');
    });
  });

  group('Accessibility (IEC 62366 / WCAG)', () {
    testWidgets('the monitor meets tap-target, label and contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final (container, platform) = await pumpScreen(tester, const MonitorScreen());
      await liveRecording(tester, container, platform);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await settle(tester);
    });

    testWidgets('the heart rate and alarms are announced to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final (container, platform) = await pumpScreen(tester, const MonitorScreen());
      await liveRecording(tester, container, platform);

      expect(find.bySemanticsLabel(RegExp('Heart rate 72 beats per minute')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Live ECG trace')), findsOneWidget);
      final banner = tester.getSemantics(find.ancestor(
        of: find.text('Device battery low'),
        matching: find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false)),
      ));
      expect(banner.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
      await settle(tester);
    });

    for (final scale in [1.5, 2.0]) {
      testWidgets('nothing overflows with ${scale}x text on the monitor', (tester) async {
        final (container, platform) = await pumpScreen(tester, const MonitorScreen(), textScale: scale);
        await liveRecording(tester, container, platform);
        expect(tester.takeException(), isNull);
        await settle(tester);
      });

      testWidgets('nothing overflows with ${scale}x text in settings', (tester) async {
        await pumpScreen(tester, const SettingsScreen(), textScale: scale);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Firmware', () {
    test('versions compare numerically', () {
      expect(compareVersions('1.10.0', '1.9.0'), 1);
      expect(compareVersions('1.1.0', '1.1.0'), 0);
      expect(compareVersions('1.0.0', '1.1.0'), -1);
      expect(compareVersions('2', '1.9.9'), 1);
    });

    test('firmware progress arrives from the native side', () {
      final e = DeviceEvent.fromMap(const {
        'type': 'firmware',
        'stage': 'waiting_for_link',
        'sent': 5120,
        'total': 98304,
        'detail': 'link lost, will resume',
      });
      expect(e, isA<FirmwareProgress>().having((p) => p.stage, 'stage', FirmwareStage.waitingForLink));
      expect((e! as FirmwareProgress).fraction, closeTo(0.052, 0.001));
    });

    test('no update while recording', () async {
      final platform = FakePlatform();
      final container = ProviderContainer(overrides: [
        deviceLinkProvider.overrideWithValue(DeviceLink(platform)),
        blobStoreProvider.overrideWithValue(MemoryBlobStore()),
      ]);
      addTearDown(container.dispose);
      container.listen(monitorProvider, (_, _) {});
      platform.emit(const LinkChanged(LinkState.connected));
      await pumpEventQueue();
      await container.read(monitorProvider.notifier).toggleStreaming();
      expect(
        () => container.read(monitorProvider.notifier).updateFirmware(Uint8List(10), '1.1.0'),
        throwsStateError,
      );
    });
  });
}
