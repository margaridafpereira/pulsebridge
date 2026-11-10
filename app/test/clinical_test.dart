import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsebridge/clinical/clinical_gate.dart';
import 'package:pulsebridge/clinical/clinical_lock.dart';
import 'package:pulsebridge/l10n/app_localizations.dart';
import 'package:pulsebridge/monitor/monitor_controller.dart' show clockProvider;
import 'package:pulsebridge/profile/profile.dart';
import 'package:pulsebridge/report/report.dart';
import 'package:pulsebridge/sessions/session.dart';
import 'package:pulsebridge/sessions/session_repository.dart';
import 'package:pulsebridge/settings/settings.dart';

class FakeBiometrics implements BiometricAuth {
  bool succeed = true;
  int prompts = 0;

  @override
  Future<bool> available() async => true;
  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeed;
  }
}

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // Test vectors from RFC 7914 §11 and the widely used RFC 6070-style SHA-256 set.
    test('matches published vectors', () {
      expect(hex(pbkdf2Sha256(utf8.encode('passwd'), utf8.encode('salt'), 1)),
          '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc');
      expect(hex(pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 4096)),
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });
  });

  group('ClinicalLockController', () {
    late MemoryBlobStore store;
    late FakeBiometrics biometrics;
    late DateTime now;

    ProviderContainer makeContainer() {
      final c = ProviderContainer(overrides: [
        blobStoreProvider.overrideWithValue(store),
        biometricAuthProvider.overrideWithValue(biometrics),
        pinIterationsProvider.overrideWithValue(1000),
        clockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
      c.listen(clinicalLockProvider, (_, _) {});
      return c;
    }

    setUp(() {
      store = MemoryBlobStore();
      biometrics = FakeBiometrics();
      now = DateTime(2026, 11, 9, 10);
    });

    test('starts without a PIN, and setting one unlocks', () async {
      final c = makeContainer();
      expect((await c.read(clinicalLockProvider.future)).configured, isFalse);
      await c.read(clinicalLockProvider.notifier).setPin('246810');
      final s = c.read(clinicalLockProvider).requireValue;
      expect(s.configured && s.unlocked, isTrue);
    });

    test('stores a salted hash, never the PIN', () async {
      final c = makeContainer();
      await c.read(clinicalLockProvider.future);
      await c.read(clinicalLockProvider.notifier).setPin('246810');
      final stored = utf8.decode(store.files[ClinicalLockController.file]!);
      expect(stored, isNot(contains('246810')));
      expect(jsonDecode(stored), containsPair('iterations', 1000));
    });

    test('rejects PINs that are not 6 digits', () async {
      final c = makeContainer();
      await c.read(clinicalLockProvider.future);
      expect(() => c.read(clinicalLockProvider.notifier).setPin('1234'), throwsArgumentError);
      expect(() => c.read(clinicalLockProvider.notifier).setPin('12345a'), throwsArgumentError);
    });

    test('wrong PIN keeps it locked; the right one opens it', () async {
      final c = makeContainer();
      await c.read(clinicalLockProvider.future);
      final lock = c.read(clinicalLockProvider.notifier);
      await lock.setPin('246810');
      lock.lock();

      final wrong = await lock.unlock('000000');
      expect(wrong, isA<WrongPin>().having((r) => r.attemptsLeft, 'attempts left', 4));
      expect(c.read(clinicalLockProvider).requireValue.unlocked, isFalse);

      expect(await lock.unlock('246810'), isA<Unlocked>());
      expect(c.read(clinicalLockProvider).requireValue.unlocked, isTrue);
      expect(c.read(clinicalLockProvider).requireValue.failures, 0);
    });

    test('five wrong PINs pause entry, even for the right PIN, and the pause doubles', () async {
      final c = makeContainer();
      await c.read(clinicalLockProvider.future);
      final lock = c.read(clinicalLockProvider.notifier);
      await lock.setPin('246810');
      lock.lock();

      for (var i = 0; i < 4; i++) {
        await lock.unlock('000000');
      }
      final fifth = await lock.unlock('000000');
      expect(fifth, isA<LockedOut>().having((r) => r.until, 'until', now.add(const Duration(seconds: 30))));
      expect(await lock.unlock('246810'), isA<LockedOut>(), reason: 'locked out even with the right PIN');

      now = now.add(const Duration(seconds: 31));
      for (var i = 0; i < 4; i++) {
        await lock.unlock('000000');
      }
      expect(await lock.unlock('000000'),
          isA<LockedOut>().having((r) => r.until, 'until', now.add(const Duration(seconds: 60))));
    });

    test('failures survive an app restart', () async {
      final first = makeContainer();
      await first.read(clinicalLockProvider.future);
      final lock = first.read(clinicalLockProvider.notifier);
      await lock.setPin('246810');
      for (var i = 0; i < 5; i++) {
        await lock.unlock('000000');
      }

      final restarted = makeContainer();
      final s = await restarted.read(clinicalLockProvider.future);
      expect(s.unlocked, isFalse, reason: 'a restart always starts locked');
      expect(s.failures, 5);
      expect(await restarted.read(clinicalLockProvider.notifier).unlock('246810'), isA<LockedOut>());
    });

    test('biometrics must be confirmed to turn on, then unlock', () async {
      final c = makeContainer();
      await c.read(clinicalLockProvider.future);
      final lock = c.read(clinicalLockProvider.notifier);
      await lock.setPin('246810');

      biometrics.succeed = false;
      expect(await lock.setBiometricEnabled(true), isFalse);
      expect(c.read(clinicalLockProvider).requireValue.biometricEnabled, isFalse);

      biometrics.succeed = true;
      expect(await lock.setBiometricEnabled(true), isTrue);
      lock.lock();
      expect(await lock.unlockWithBiometrics(), isTrue);
      expect(c.read(clinicalLockProvider).requireValue.unlocked, isTrue);
    });

    test('biometrics do not bypass a lockout', () async {
      final c = makeContainer();
      await c.read(clinicalLockProvider.future);
      final lock = c.read(clinicalLockProvider.notifier);
      await lock.setPin('246810');
      await lock.setBiometricEnabled(true);
      lock.lock();
      for (var i = 0; i < 5; i++) {
        await lock.unlock('000000');
      }
      final prompts = biometrics.prompts;
      expect(await lock.unlockWithBiometrics(), isFalse);
      expect(biometrics.prompts, prompts, reason: 'no prompt while locked out');
    });
  });

  group('ClinicalGate', () {
    testWidgets('asks for a new PIN twice, then shows the clinical area, and locks again', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(overrides: [
        blobStoreProvider.overrideWithValue(MemoryBlobStore()),
        biometricAuthProvider.overrideWithValue(FakeBiometrics()),
        pinIterationsProvider.overrideWithValue(10),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClinicalGate(child: Text('Session list')),
        ),
      ));
      await tester.pump();

      // PIN hashing runs in an isolate, which needs real time.
      Future<void> enter(String pin) async {
        for (final d in pin.split('')) {
          await tester.tap(find.text(d));
          await tester.pump();
        }
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump();
      }

      expect(find.text('Protect the clinical area'), findsOneWidget);
      expect(find.text('Session list'), findsNothing);
      await enter('135790');
      expect(find.text('Confirm the PIN'), findsOneWidget);
      await enter('135790');
      expect(find.text('Session list'), findsOneWidget);

      container.read(clinicalLockProvider.notifier).lock();
      await tester.pump();
      expect(find.text('Clinical area locked'), findsOneWidget);
      expect(find.text('Session list'), findsNothing);

      await enter('111111');
      expect(find.textContaining('Wrong PIN'), findsOneWidget);
      await enter('135790');
      expect(find.text('Session list'), findsOneWidget);
    });
  });

  group('PDF report', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    Session session({List<SessionEvent> events = const []}) => Session(
          id: 's1',
          start: DateTime(2026, 11, 9, 10, 30),
          duration: const Duration(seconds: 60),
          sampleRate: 250,
          deviceId: 'PB-SIM-0001',
          heartRate: [for (var i = 0; i < 60; i++) HeartRatePoint(i * 1000, 60 + i % 20)],
          events: events,
          ectopicBeats: 12,
          lostSamples: 250,
          totalSamples: 15000,
        );

    SessionEcg ecg() {
      final samples = Int16List(15000);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = i % 200 < 6 ? 1200 : 0; // a spike every 0.8 s
      }
      samples.fillRange(5000, 5250, SessionEcg.gap);
      return SessionEcg(samples, 250);
    }

    test('builds a PDF with the session, the profile and a strip per symptom', () async {
      final bytes = await buildReport(
        ReportInput(
          session: session(events: const [
            SessionEvent(20000, SessionEventKind.symptom, 'Palpitations'),
            SessionEvent(21000, SessionEventKind.alarm, 'LEAD_OFF'),
            SessionEvent(30000, SessionEventKind.heartRate, 'Premature beat'),
          ]),
          ecg: ecg(),
          profile: const PatientProfile(name: 'Ana Silva', birthYear: 1990, conditions: ['Palpitations']),
          settings: const AppSettings(),
          generatedAt: DateTime(2026, 11, 9, 12),
        ),
        lookupAppLocalizations(const Locale('en')),
        theme: await loadReportTheme(),
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(10000));
    });

    test('works with no profile, no events and no ECG', () async {
      final bytes = await buildReport(
        ReportInput(
          session: session(),
          ecg: null,
          profile: const PatientProfile(),
          settings: const AppSettings(),
          generatedAt: DateTime(2026, 11, 9, 12),
        ),
        lookupAppLocalizations(const Locale('en')),
        theme: await loadReportTheme(),
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
