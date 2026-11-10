import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/app_localizations.dart';
import '../l10n/display.dart';
import '../profile/profile.dart';
import '../sessions/session.dart';
import '../sessions/sessions_screen.dart' show formatDate, formatDuration;
import '../settings/settings.dart';

/// Everything one report needs. The report covers exactly one session.
class ReportInput {
  const ReportInput({
    required this.session,
    required this.ecg,
    required this.profile,
    required this.settings,
    required this.generatedAt,
  });

  final Session session;
  final SessionEcg? ecg;
  final PatientProfile profile;
  final AppSettings settings;
  final DateTime generatedAt;
}

/// Bundled fonts, so the report renders the same everywhere (the PDF base
/// fonts have no "µ", "–" or "·").
Future<pw.ThemeData> loadReportTheme() async => pw.ThemeData.withFont(
      base: pw.Font.ttf(await rootBundle.load('assets/fonts/roboto-regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/roboto-bold.ttf')),
    );

const _mm = PdfPageFormat.mm;
const _ink = PdfColor.fromInt(0xFF1B1F23);
const _muted = PdfColor.fromInt(0xFF6A737D);
const _accent = PdfColor.fromInt(0xFF1E8E3E);
const _warn = PdfColor.fromInt(0xFFB26A00);
const _rule = PdfColor.fromInt(0xFFD0D7DE);
const _gridMinor = PdfColor.fromInt(0xFFF7D4D4);
const _gridMajor = PdfColor.fromInt(0xFFE8A0A0);

/// Strips are printed at clinical scale: 25 mm/s and 10 mm/mV.
const stripSeconds = 6;
const _stripHeightMm = 30.0;

/// The most symptom and alarm strips in one report, to bound its size.
const maxStrips = 8;

/// Builds the report in the language of [l].
Future<Uint8List> buildReport(ReportInput input, AppLocalizations l, {required pw.ThemeData theme}) async {
  final s = input.session;
  final doc = pw.Document(
    title: '${l.reportPdfTitle} ${formatDate(s.start)}',
    author: 'PulseBridge',
    creator: 'PulseBridge',
    subject: l.reportPdfTitle,
  );

  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(15 * _mm, 14 * _mm, 15 * _mm, 14 * _mm),
      theme: theme.copyWith(defaultTextStyle: const pw.TextStyle(fontSize: 9, color: _ink)),
    ),
    header: (context) => _header(l, input, context),
    footer: (context) => _footer(l, context),
    build: (context) => [
      _patient(l, input),
      pw.SizedBox(height: 10),
      _recording(l, input),
      pw.SizedBox(height: 10),
      _summary(l, s),
      pw.SizedBox(height: 14),
      _heading(l.sectionHeartRate),
      _heartRateChart(l, s, input.settings),
      pw.SizedBox(height: 14),
      ..._strips(l, input),
      _heading(l.eventLog),
      _eventTable(l, s),
    ],
  ));

  return doc.save();
}

pw.Widget _header(AppLocalizations l, ReportInput input, pw.Context context) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 1.5))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('PulseBridge', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _accent)),
          pw.Text(l.reportPdfTitle, style: const pw.TextStyle(fontSize: 10, color: _muted)),
        ]),
        pw.Spacer(),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          if (input.profile.name.isNotEmpty)
            pw.Text(input.profile.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(l.recordedOn(formatDate(input.session.start)), style: const pw.TextStyle(color: _muted)),
        ]),
      ]),
    );

pw.Widget _footer(AppLocalizations l, pw.Context context) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _rule, width: 0.5))),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Text(
            l.disclaimer,
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
        ),
        pw.Text(l.pageOf(context.pageNumber, context.pagesCount),
            style: const pw.TextStyle(fontSize: 7, color: _muted)),
      ]),
    );

pw.Widget _heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _box(String title, List<(String, String)> rows) => pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _rule, width: 0.5), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title.toUpperCase(),
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _muted, letterSpacing: 0.8)),
        pw.SizedBox(height: 5),
        for (final (label, value) in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2.5),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(width: 32 * _mm, child: pw.Text(label, style: const pw.TextStyle(color: _muted))),
              pw.Expanded(child: pw.Text(value.isEmpty ? '—' : value)),
            ]),
          ),
      ]),
    );

pw.Widget _patient(AppLocalizations l, ReportInput input) {
  final p = input.profile;
  if (p.isEmpty) return _box(l.patient, [(l.profileLabel, l.noProfile)]);
  final age = p.age(input.session.start);
  return _box(l.patient, [
    (l.name, p.name),
    (l.ageSex, [if (age != null) l.ageBorn(age, p.birthYear!), if (p.sex != null) sexName(l, p.sex!)].join(' · ')),
    (l.conditions, [for (final c in p.conditions) conditionName(l, c)].join(', ')),
    (l.medication, p.medications.join(', ')),
    (l.physician, p.physician),
    (l.emergencyContact, p.emergencyContact),
  ]);
}

pw.Widget _recording(AppLocalizations l, ReportInput input) {
  final s = input.session;
  return _box(l.recording, [
    (l.start, formatDate(s.start)),
    (l.statDuration, formatDuration(s.duration)),
    (l.device, l.deviceDesc(s.deviceId, s.sampleRate)),
    (l.alarmLimits, l.bpmRange(input.settings.hrLow, input.settings.hrHigh)),
    (l.signalLost, l.signalLostValue(s.lostPercent.toStringAsFixed(1), s.lostSamples, s.totalSamples)),
  ]);
}

pw.Widget _summary(AppLocalizations l, Session s) {
  pw.Widget tile(String label, String value, String unit, {PdfColor color = _ink}) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F8FA)),
          child: pw.Column(children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: _muted)),
            pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(text: value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: color)),
                if (unit.isNotEmpty) pw.TextSpan(text: ' $unit', style: const pw.TextStyle(fontSize: 7, color: _muted)),
              ]),
            ),
          ]),
        ),
      );

  final findings = <String>[
    if (s.ectopicBeats > 0) l.findingPremature(s.ectopicBeats) else l.findingNoPremature,
    if (s.alarmCount > 0) l.findingAlarms(s.alarmCount),
    if (s.symptomCount > 0) l.findingSymptoms(s.symptomCount),
  ];

  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Row(children: [
      tile(l.averageHr, '${s.avgBpm ?? '--'}', l.bpm, color: _accent),
      tile(l.minHr, '${s.minBpm ?? '--'}', l.bpm),
      tile(l.maxHr, '${s.maxBpm ?? '--'}', l.bpm),
      tile(l.prematureBeatsLabel, '${s.ectopicBeats}', '', color: s.ectopicBeats > 0 ? _warn : _ink),
      tile(l.symptomsLabel, '${s.symptomCount}', ''),
      tile(l.alarmsLabel, '${s.alarmCount}', '', color: s.alarmCount > 0 ? _warn : _ink),
    ]),
    pw.SizedBox(height: 8),
    for (final f in findings) pw.Bullet(text: f, style: const pw.TextStyle(fontSize: 9), bulletSize: 3),
  ]);
}

pw.Widget _heartRateChart(AppLocalizations l, Session s, AppSettings settings) {
  if (s.heartRate.length < 2) return pw.Text(l.notEnoughHr);
  final points = [for (final p in s.heartRate) pw.PointChartValue(p.atMs / 60000, p.bpm.toDouble())];
  final minutes = max(s.duration.inMilliseconds / 60000, points.last.x);
  final lo = (min(s.minBpm!, settings.hrLow) ~/ 20) * 20;
  final hi = ((max(s.maxBpm!, settings.hrHigh) + 19) ~/ 20) * 20;
  final xStep = minutes <= 2 ? 0.5 : minutes <= 10 ? 1 : minutes <= 60 ? 5 : 15;
  // Round the axis up to a whole step so the last readings are not cut off.
  final xEnd = (minutes / xStep).ceil() * xStep;
  final xTicks = [for (var x = 0.0; x <= xEnd + 1e-9; x += xStep) x];
  String mmss(num m) => '${m.floor()}:${((m - m.floor()) * 60).round().toString().padLeft(2, '0')}';

  pw.LineDataSet limit(int bpm) => pw.LineDataSet(
        data: [pw.PointChartValue(0, bpm.toDouble()), pw.PointChartValue(xTicks.last, bpm.toDouble())],
        drawPoints: false,
        lineWidth: 0.6,
        color: PdfColors.red300,
      );

  return pw.SizedBox(
    height: 45 * _mm,
    child: pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis(xTicks, format: mmss, divisions: true, divisionsColor: _rule, textStyle: const pw.TextStyle(fontSize: 7, color: _muted)),
        yAxis: pw.FixedAxis([for (var y = lo; y <= hi; y += 20) y], divisions: true, divisionsColor: _rule, textStyle: const pw.TextStyle(fontSize: 7, color: _muted)),
      ),
      datasets: [
        limit(settings.hrLow),
        limit(settings.hrHigh),
        pw.LineDataSet(data: points, drawPoints: false, lineWidth: 1, color: _accent, isCurved: false),
      ],
    ),
  );
}

/// One strip per symptom and alarm, centred on the event. With none, the
/// first seconds of the recording, so the report always shows the signal.
List<pw.Widget> _strips(AppLocalizations l, ReportInput input) {
  final ecg = input.ecg;
  if (ecg == null || ecg.samples.isEmpty) return [];
  final events = input.session.events
      .where((e) => e.kind == SessionEventKind.symptom || e.kind == SessionEventKind.alarm)
      .take(maxStrips)
      .toList();
  final strips = events.isEmpty
      ? [(0, l.startOfRecording, null)]
      : [for (final e in events) (e.atMs - stripSeconds * 500, eventText(l, e), e)];

  return [
    _heading(l.ecgLabel),
    pw.Text(l.ecgScaleNote, style: const pw.TextStyle(fontSize: 8, color: _muted)),
    pw.SizedBox(height: 6),
    for (final (startMs, label, event) in strips)
      // A strip and its title stay on one page.
      pw.Inseparable(child: pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(children: [
            if (event != null)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                margin: const pw.EdgeInsets.only(right: 5),
                decoration: pw.BoxDecoration(
                  color: event.kind == SessionEventKind.symptom ? PdfColors.blue50 : PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(event.kind == SessionEventKind.symptom ? l.symptomTag : l.alarmTag,
                    style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
              ),
            pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Spacer(),
            pw.Text(
              event == null ? '${_clock(0)} – ${_clock(stripSeconds * 1000)}' : l.atTime(_clock(event.atMs)),
              style: const pw.TextStyle(color: _muted),
            ),
          ]),
          pw.SizedBox(height: 3),
          _ecgStrip(ecg, max(0, startMs)),
        ]),
      )),
  ];
}

pw.Widget _ecgStrip(SessionEcg ecg, int startMs) {
  final rate = ecg.sampleRate;
  final first = min(startMs * rate ~/ 1000, max(0, ecg.samples.length - stripSeconds * rate));
  final count = min(stripSeconds * rate, ecg.samples.length - first);
  final window = Int16List.sublistView(ecg.samples, first, first + count);

  // Remove the baseline with the median, which ignores the QRS spikes.
  final valid = [for (final v in window) if (v != SessionEcg.gap) v]..sort();
  final baseline = valid.isEmpty ? 0 : valid[valid.length ~/ 2];

  const calibration = 6 * _mm; // room for the 1 mV pulse before the trace
  const width = calibration + stripSeconds * 25.0 * _mm;
  const height = _stripHeightMm * _mm;

  return pw.CustomPaint(
    size: const PdfPoint(width, height),
    painter: (canvas, size) {
      // PDF coordinates: origin bottom-left, y up.
      for (var mm = 0; mm * _mm <= size.x + 0.01; mm++) {
        final major = mm % 5 == 0;
        canvas
          ..setStrokeColor(major ? _gridMajor : _gridMinor)
          ..setLineWidth(major ? 0.45 : 0.2)
          ..drawLine(mm * _mm, 0, mm * _mm, size.y)
          ..strokePath();
      }
      for (var mm = 0; mm <= _stripHeightMm; mm++) {
        final major = mm % 5 == 0;
        canvas
          ..setStrokeColor(major ? _gridMajor : _gridMinor)
          ..setLineWidth(major ? 0.45 : 0.2)
          ..drawLine(0, mm * _mm, size.x, mm * _mm)
          ..strokePath();
      }

      canvas
        ..saveContext()
        ..drawRect(0, 0, size.x, size.y)
        ..clipPath();

      final dx = (size.x - calibration) / (stripSeconds * rate);
      const perMicrovolt = 10 * _mm / 1000; // 10 mm per mV
      final mid = size.y * 0.45;

      // Lost samples: a grey band, never a line.
      canvas.setFillColor(const PdfColor(0.6, 0.6, 0.6, 0.35));
      int? gapStart;
      for (var i = 0; i <= window.length; i++) {
        final isGap = i < window.length && window[i] == SessionEcg.gap;
        if (isGap && gapStart == null) gapStart = i;
        if (!isGap && gapStart != null) {
          canvas
            ..drawRect(calibration + gapStart * dx, 0, (i - gapStart) * dx, size.y)
            ..fillPath();
          gapStart = null;
        }
      }

      canvas
        ..setStrokeColor(PdfColors.black)
        ..setLineWidth(0.6)
        ..setLineJoin(PdfLineJoin.round);
      var penDown = false;
      for (var i = 0; i < window.length; i++) {
        final v = window[i];
        if (v == SessionEcg.gap) {
          penDown = false;
          continue;
        }
        final x = calibration + i * dx;
        final y = mid + (v - baseline) * perMicrovolt;
        penDown ? canvas.lineTo(x, y) : canvas.moveTo(x, y);
        penDown = true;
      }
      canvas
        ..strokePath()
        ..restoreContext();

      // 1 mV calibration pulse, 10 mm tall.
      canvas
        ..setStrokeColor(PdfColors.black)
        ..setLineWidth(0.6)
        ..moveTo(0.5 * _mm, mid)
        ..lineTo(1.5 * _mm, mid)
        ..lineTo(1.5 * _mm, mid + 10 * _mm)
        ..lineTo(4.5 * _mm, mid + 10 * _mm)
        ..lineTo(4.5 * _mm, mid)
        ..lineTo(5.5 * _mm, mid)
        ..strokePath();
    },
  );
}

pw.Widget _eventTable(AppLocalizations l, Session s) {
  final events = s.events.where((e) => e.kind != SessionEventKind.heartRate).toList();
  if (events.isEmpty) return pw.Text(l.noEvents);
  final kinds = {
    SessionEventKind.alarm: l.kindAlarm,
    SessionEventKind.link: l.kindLink,
    SessionEventKind.symptom: l.kindSymptom,
    SessionEventKind.info: l.kindInfo,
    SessionEventKind.heartRate: l.kindRhythm,
  };
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.TableHelper.fromTextArray(
      headers: [l.time, l.type, l.event],
      data: [for (final e in events) [_clock(e.atMs), kinds[e.kind]!, eventText(l, e)]],
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: _muted),
      headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule))),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.3))),
      columnWidths: {0: const pw.FixedColumnWidth(40), 1: const pw.FixedColumnWidth(55), 2: const pw.FlexColumnWidth()},
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft},
    ),
    if (s.ectopicBeats > 0)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(l.prematureNotListed(s.ectopicBeats),
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ),
  ]);
}

String _clock(int ms) {
  final s = ms ~/ 1000;
  final h = s ~/ 3600;
  final mmss = '${(s % 3600) ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  return h > 0 ? '$h:${mmss.padLeft(5, '0')}' : mmss;
}
