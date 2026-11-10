import 'dart:typed_data';

/// One recording, as stored. Times are milliseconds since the recording started.
class Session {
  Session({
    required this.id,
    required this.start,
    required this.duration,
    required this.sampleRate,
    required this.deviceId,
    required this.heartRate,
    required this.events,
    required this.ectopicBeats,
    required this.lostSamples,
    required this.totalSamples,
  });

  final String id;
  final DateTime start;
  final Duration duration;
  final int sampleRate;
  final String deviceId;
  final List<HeartRatePoint> heartRate;
  final List<SessionEvent> events;
  final int ectopicBeats;
  final int lostSamples;
  final int totalSamples;

  int? get minBpm => heartRate.isEmpty ? null : heartRate.map((p) => p.bpm).reduce((a, b) => a < b ? a : b);
  int? get maxBpm => heartRate.isEmpty ? null : heartRate.map((p) => p.bpm).reduce((a, b) => a > b ? a : b);
  int? get avgBpm =>
      heartRate.isEmpty ? null : (heartRate.map((p) => p.bpm).reduce((a, b) => a + b) / heartRate.length).round();
  int get alarmCount => events.where((e) => e.kind == SessionEventKind.alarm).length;
  int get symptomCount => events.where((e) => e.kind == SessionEventKind.symptom).length;
  double get lostPercent => totalSamples == 0 ? 0 : 100 * lostSamples / totalSamples;

  Map<String, Object?> toJson() => {
        'version': 1,
        'id': id,
        'start': start.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'sampleRate': sampleRate,
        'deviceId': deviceId,
        'heartRate': [for (final p in heartRate) [p.atMs, p.bpm]],
        'events': [for (final e in events) {'atMs': e.atMs, 'kind': e.kind.name, 'text': e.text}],
        'ectopicBeats': ectopicBeats,
        'lostSamples': lostSamples,
        'totalSamples': totalSamples,
      };

  factory Session.fromJson(Map<String, Object?> json) => Session(
        id: json['id']! as String,
        start: DateTime.parse(json['start']! as String),
        duration: Duration(milliseconds: json['durationMs']! as int),
        sampleRate: json['sampleRate']! as int,
        deviceId: json['deviceId']! as String,
        heartRate: [
          for (final p in json['heartRate']! as List) HeartRatePoint((p as List)[0] as int, p[1] as int),
        ],
        events: [
          for (final e in json['events']! as List)
            SessionEvent(
              (e as Map)['atMs'] as int,
              SessionEventKind.values.byName(e['kind'] as String),
              e['text'] as String,
            ),
        ],
        ectopicBeats: json['ectopicBeats']! as int,
        lostSamples: json['lostSamples']! as int,
        totalSamples: json['totalSamples']! as int,
      );
}

class HeartRatePoint {
  const HeartRatePoint(this.atMs, this.bpm);
  final int atMs;
  final int bpm;
}

enum SessionEventKind { alarm, link, heartRate, symptom, info }

class SessionEvent {
  const SessionEvent(this.atMs, this.kind, this.text);
  final int atMs;
  final SessionEventKind kind;
  final String text;
}

/// Raw ECG of a session: int16 microvolts, [gap] where samples were lost.
class SessionEcg {
  SessionEcg(this.samples, this.sampleRate);

  static const gap = -32768;

  final Int16List samples;
  final int sampleRate;

  Duration get duration => Duration(milliseconds: samples.length * 1000 ~/ sampleRate);
}
