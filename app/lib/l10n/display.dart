import 'package:intl/intl.dart';

import '../sessions/session.dart';
import 'app_localizations.dart';

/// Stored data (event texts, symptoms, conditions) stays in English so a
/// recording reads the same whatever the phone's language; it is translated
/// only when shown.

String symptomName(AppLocalizations l, String key) => switch (key) {
      'Palpitations' => l.symptomPalpitations,
      'Dizziness' => l.symptomDizziness,
      'Chest pain' => l.symptomChestPain,
      'Shortness of breath' => l.symptomShortnessOfBreath,
      'Fatigue' => l.symptomFatigue,
      'Exercise' => l.symptomExercise,
      _ => key,
    };

String conditionName(AppLocalizations l, String key) => switch (key) {
      'Hypertension' => l.condHypertension,
      'Atrial fibrillation' => l.condAtrialFibrillation,
      'Diabetes' => l.condDiabetes,
      'Heart failure' => l.condHeartFailure,
      'Asthma' => l.condAsthma,
      _ => key,
    };

String sexName(AppLocalizations l, String key) => switch (key) {
      'Female' => l.sexFemale,
      'Male' => l.sexMale,
      'Other' => l.sexOther,
      _ => key,
    };

final _hrOutside = RegExp(r'^Heart rate (\d+) bpm outside (\d+)–(\d+)$');

String eventText(AppLocalizations l, SessionEvent e) {
  if (e.kind == SessionEventKind.symptom) return symptomName(l, e.text);
  final hr = _hrOutside.firstMatch(e.text);
  if (hr != null) return l.eventHrOutside(int.parse(hr[1]!), int.parse(hr[2]!), int.parse(hr[3]!));
  if (e.text.startsWith('Link lost: ')) return l.eventLinkLostReason(e.text.substring('Link lost: '.length));
  return switch (e.text) {
    'Recording started' => l.eventRecordingStarted,
    'Recording stopped' => l.eventRecordingStopped,
    'Device connected' => l.eventDeviceConnected,
    'Reconnecting' => l.eventReconnecting,
    'Link lost' => l.eventLinkLost,
    'Electrode off' => l.electrodeOff,
    'Electrode off cleared' => l.eventElectrodeOffCleared,
    'Low battery' => l.eventLowBattery,
    'Low battery cleared' => l.eventLowBatteryCleared,
    'Premature beat' => l.eventPremature,
    _ => e.text,
  };
}

/// "9 Nov 2026 · 10:30" in English, "9/11/2026 · 10:30" style per locale.
String formatDateFor(String locale, DateTime d) =>
    '${DateFormat.yMMMd(locale).format(d)} · ${DateFormat.Hm(locale).format(d)}';
