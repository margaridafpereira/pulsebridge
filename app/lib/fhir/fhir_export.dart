import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../profile/profile.dart';
import '../sessions/session.dart';

/// Code systems used in the export.
const loinc = 'http://loinc.org';
const snomed = 'http://snomed.info/sct';
const ucum = 'http://unitsofmeasure.org';

/// ISO/IEEE 11073-10101 (MDC), the nomenclature FHIR uses for ECG waveforms.
const mdc = 'urn:oid:2.16.840.1.113883.6.24';
const observationCategory = 'http://terminology.hl7.org/CodeSystem/observation-category';

/// SNOMED CT concepts for the symptoms the patient can log.
const symptomCodes = {
  'Palpitations': ('80313002', 'Palpitations'),
  'Dizziness': ('404640003', 'Dizziness'),
  'Chest pain': ('29857009', 'Chest pain'),
  'Shortness of breath': ('267036007', 'Dyspnea'),
  'Fatigue': ('84229001', 'Fatigue'),
  // "Exercise" is context, not a symptom: exported as text only.
};

/// One recording as a FHIR R4 transaction Bundle, ready to POST to a FHIR
/// server or to share as a file (SRS-023):
///
/// - Patient and Device;
/// - Observation: mean heart rate (vital-signs profile, LOINC 8867-4);
/// - Observation: heart rate over time, 1 Hz SampledData;
/// - Observation: the ECG, lead II in µV as SampledData (MDC 131330), lost
///   samples written as "E" (error) so they are never read as signal;
/// - Observation per symptom (LOINC 75325-1 with a SNOMED CT value);
/// - Observation: premature beats flagged by the screening;
/// - DiagnosticReport tying the results together.
///
/// Resources reference each other through urn:uuid full URLs, which the
/// server replaces with real ids when it processes the transaction.
class FhirExport {
  FhirExport({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  Map<String, Object?> bundle({
    required Session session,
    required SessionEcg? ecg,
    required PatientProfile profile,
    required DateTime generatedAt,
  }) {
    final entries = <Map<String, Object?>>[];
    String add(Map<String, Object?> resource) {
      final url = 'urn:uuid:${_uuid()}';
      entries.add({
        'fullUrl': url,
        'resource': resource,
        'request': {'method': 'POST', 'url': resource['resourceType']},
      });
      return url;
    }

    final start = session.start;
    final end = start.add(session.duration);
    final period = {'start': fhirDateTime(start), 'end': fhirDateTime(end)};

    final patient = add(_patient(profile));
    final device = add({
      'resourceType': 'Device',
      'deviceName': [
        {'name': session.deviceId, 'type': 'user-friendly-name'},
      ],
      'type': {'text': session.sampleRate > 0 && (ecg?.samples.isNotEmpty ?? false)
          ? 'Single-lead ECG monitor'
          : 'Heart-rate sensor'},
    });
    Map<String, Object?> observation(Map<String, Object?> fields) => {
          'resourceType': 'Observation',
          'status': 'final',
          ...fields,
          'subject': {'reference': patient},
          'device': {'reference': device},
        };

    final results = <String>[];
    final avg = session.avgBpm;
    if (avg != null) {
      results.add(add(observation({
        'meta': {
          'profile': ['http://hl7.org/fhir/StructureDefinition/heartrate'],
        },
        'category': [_category('vital-signs', 'Vital Signs')],
        'code': _code(loinc, '8867-4', 'Heart rate'),
        'effectivePeriod': period,
        'valueQuantity': _quantity(avg, 'beats/minute', '/min'),
        'note': [
          {'text': 'Mean over the recording; range ${session.minBpm}–${session.maxBpm} /min.'},
        ],
      })));

      results.add(add(observation({
        'category': [_category('procedure', 'Procedure')],
        'code': _code(loinc, '8867-4', 'Heart rate'),
        'effectivePeriod': period,
        'valueSampledData': {
          'origin': _quantity(0, 'beats/minute', '/min'),
          'period': 1000,
          'dimensions': 1,
          'data': _heartRatePerSecond(session),
        },
      })));
    }

    if (ecg != null && ecg.samples.isNotEmpty) {
      results.add(add(observation({
        'category': [_category('procedure', 'Procedure')],
        'code': {
          'coding': [
            {'system': loinc, 'code': '11524-6', 'display': 'EKG study'},
            {'system': mdc, 'code': '131328', 'display': 'MDC_ECG_ELEC_POTL'},
          ],
          'text': 'Single-lead ECG',
        },
        'effectivePeriod': period,
        'component': [
          {
            'code': _code(mdc, '131330', 'MDC_ECG_ELEC_POTL_II', text: 'Lead II'),
            'valueSampledData': {
              'origin': _quantity(0, 'microvolt', 'uV'),
              'period': 1000 / ecg.sampleRate,
              'factor': 1,
              'lowerLimit': -32767,
              'upperLimit': 32767,
              'dimensions': 1,
              'data': [for (final v in ecg.samples) v == SessionEcg.gap ? 'E' : '$v'].join(' '),
            },
          },
        ],
      })));
    }

    for (final e in session.events.where((e) => e.kind == SessionEventKind.symptom)) {
      final coded = symptomCodes[e.text];
      results.add(add(observation({
        'category': [_category('survey', 'Survey')],
        'code': _code(loinc, '75325-1', 'Symptom'),
        'effectiveDateTime': fhirDateTime(start.add(Duration(milliseconds: e.atMs))),
        'valueCodeableConcept': coded == null
            ? {'text': e.text}
            : _code(snomed, coded.$1, coded.$2, text: e.text),
        'note': [
          {'text': 'Reported by the patient ${_clock(e.atMs)} into the recording.'},
        ],
      })));
    }

    results.add(add(observation({
      'category': [_category('procedure', 'Procedure')],
      'code': {'text': 'Premature beats flagged by rhythm screening'},
      'effectivePeriod': period,
      'valueQuantity': {'value': session.ectopicBeats, 'unit': 'beats', 'system': ucum, 'code': '{beats}'},
      'method': {'text': 'RR interval below 80 % of the median of the last 8 normal intervals'},
      'note': [
        {'text': 'Screening indicator, not a diagnosis.'},
      ],
    })));

    add({
      'resourceType': 'DiagnosticReport',
      'status': 'final',
      'category': [
        {
          'coding': [
            {'system': 'http://terminology.hl7.org/CodeSystem/v2-0074', 'code': 'EC', 'display': 'Electrocardiac (e.g., EKG, EEC, Holter)'},
          ],
          'text': 'Electrocardiac',
        },
      ],
      'code': _code(loinc, '11524-6', 'EKG study', text: 'Ambulatory single-lead ECG recording'),
      'subject': {'reference': patient},
      'effectivePeriod': period,
      'issued': fhirDateTime(generatedAt),
      'result': [for (final r in results) {'reference': r}],
      'conclusion': _conclusion(session),
    });

    return {
      'resourceType': 'Bundle',
      'type': 'transaction',
      'timestamp': fhirDateTime(generatedAt),
      'entry': entries,
    };
  }

  Map<String, Object?> _patient(PatientProfile p) {
    final parts = p.name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    return {
      'resourceType': 'Patient',
      if (parts.isNotEmpty)
        'name': [
          {
            'text': p.name.trim(),
            'family': parts.last,
            if (parts.length > 1) 'given': parts.sublist(0, parts.length - 1),
          },
        ],
      'gender': switch (p.sex?.toLowerCase()) {
        'female' => 'female',
        'male' => 'male',
        'other' => 'other',
        _ => 'unknown',
      },
      if (p.birthYear != null) 'birthDate': '${p.birthYear}',
    };
  }

  /// Last reading in each second; "E" where there was none yet.
  static String _heartRatePerSecond(Session s) {
    final seconds = (s.duration.inMilliseconds / 1000).ceil();
    final out = List<String>.filled(max(seconds, 1), 'E');
    var j = 0;
    int? current;
    for (var sec = 0; sec < out.length; sec++) {
      while (j < s.heartRate.length && s.heartRate[j].atMs < (sec + 1) * 1000) {
        current = s.heartRate[j].bpm;
        j++;
      }
      if (current != null) out[sec] = '$current';
    }
    return out.join(' ');
  }

  static String _conclusion(Session s) => [
        if (s.avgBpm != null) 'Mean heart rate ${s.avgBpm} /min (${s.minBpm}–${s.maxBpm}).',
        '${s.ectopicBeats} premature beats flagged.',
        if (s.symptomCount > 0) '${s.symptomCount} symptoms reported.',
        if (s.lostSamples > 0) '${s.lostPercent.toStringAsFixed(1)} % of the signal lost.',
        'Screening indicators, not a diagnosis.',
      ].join(' ');

  static Map<String, Object?> _code(String system, String code, String display, {String? text}) => {
        'coding': [
          {'system': system, 'code': code, 'display': display},
        ],
        'text': text ?? display,
      };

  static Map<String, Object?> _category(String code, String display) => {
        'coding': [
          {'system': observationCategory, 'code': code, 'display': display},
        ],
      };

  static Map<String, Object?> _quantity(num value, String unit, String code) =>
      {'value': value, 'unit': unit, 'system': ucum, 'code': code};

  String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0F) | 0x40; // version 4
    b[8] = (b[8] & 0x3F) | 0x80; // RFC 4122 variant
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static String _clock(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// FHIR dateTime with the local UTC offset, e.g. 2026-11-09T10:30:00+00:00.
String fhirDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final o = t.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  final oh = two(o.inHours.abs()), om = two(o.inMinutes.abs() % 60);
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}$sign$oh:$om';
}

/// Result of posting a bundle to a FHIR server.
class FhirSendResult {
  const FhirSendResult(this.status, this.created, [this.error]);
  final int status;

  /// Locations the server gave the new resources, e.g. Observation/123/_history/1.
  final List<String> created;
  final String? error;
  bool get ok => status >= 200 && status < 300 && error == null;
}

/// POSTs a transaction bundle to the server's base URL. Only https is allowed,
/// so health data never travels in clear text.
Future<FhirSendResult> sendBundle(Uri base, Map<String, Object?> bundle, {HttpClient? client}) async {
  if (base.scheme != 'https' && base.host != 'localhost' && base.host != '127.0.0.1') {
    return const FhirSendResult(0, [], 'The FHIR server must use https');
  }
  final http = client ?? HttpClient();
  http.connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await http.postUrl(base);
    request.headers
      ..contentType = ContentType('application', 'fhir+json', charset: 'utf-8')
      ..set(HttpHeaders.acceptHeader, 'application/fhir+json');
    request.add(utf8.encode(jsonEncode(bundle)));
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return FhirSendResult(response.statusCode, const [], _operationOutcome(body) ?? 'HTTP ${response.statusCode}');
    }
    final json = jsonDecode(body) as Map<String, Object?>;
    final created = [
      for (final e in (json['entry'] as List? ?? const []))
        if ((e as Map)['response'] case {'location': final String location}) location,
    ];
    return FhirSendResult(response.statusCode, created);
  } on Exception catch (e) {
    return FhirSendResult(0, const [], '$e');
  } finally {
    if (client == null) http.close();
  }
}

String? _operationOutcome(String body) {
  try {
    final json = jsonDecode(body) as Map<String, Object?>;
    final issues = json['issue'] as List?;
    return issues?.map((i) => (i as Map)['diagnostics'] ?? i['details']?['text']).whereType<String>().join('; ');
  } on FormatException {
    return null;
  }
}
