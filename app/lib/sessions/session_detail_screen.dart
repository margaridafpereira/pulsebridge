import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fhir/fhir_screen.dart';
import '../l10n/display.dart';
import '../l10n/l10n.dart';
import '../report/report_screen.dart';
import '../settings/settings.dart';
import '../theme.dart';
import '../widgets/ecg_strip.dart';
import '../widgets/trend_chart.dart';
import 'session.dart';
import 'sessions_provider.dart';
import 'sessions_screen.dart';

final _ecgProvider = FutureProvider.autoDispose.family<SessionEcg?, Session>(
  (ref, session) => ref.watch(sessionRepositoryProvider).loadEcg(session),
);

class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.session});
  final Session session;

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  static const _stripSeconds = 6;
  double _position = 0; // seconds into the recording

  Session get session => widget.session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final ecg = ref.watch(_ecgProvider(session));

    return Scaffold(
      appBar: AppBar(
        title: Text(formatDate(session.start), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: l.pdfReport,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => ReportScreen(session: session)),
            ),
          ),
          IconButton(
            tooltip: l.fhirExport,
            icon: const Icon(Icons.local_hospital_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => FhirScreen(session: session)),
            ),
          ),
          IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDelete(context) != true) return;
              await ref.read(sessionRepositoryProvider).delete(session);
              ref.invalidate(sessionsProvider);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // Three columns that grow with the text instead of a fixed-ratio grid.
          LayoutBuilder(builder: (context, c) => Wrap(spacing: 10, runSpacing: 10, children: [
            for (final tile in [
              StatTile(label: l.statAverage, value: '${session.avgBpm ?? '--'}', unit: l.bpm, color: AppColors.ecg),
              StatTile(label: l.statMinShort, value: '${session.minBpm ?? '--'}', unit: l.bpm),
              StatTile(label: l.statMaxShort, value: '${session.maxBpm ?? '--'}', unit: l.bpm),
              StatTile(label: l.statDuration, value: formatDuration(session.duration)),
              StatTile(
                label: l.statPremature,
                value: '${session.ectopicBeats}',
                color: session.ectopicBeats > 0 ? AppColors.warning : AppColors.textPrimary,
              ),
              StatTile(
                label: l.statDataLost,
                value: session.lostPercent.toStringAsFixed(1),
                unit: '%',
                color: session.lostSamples > 0 ? AppColors.warning : AppColors.textPrimary,
              ),
            ])
              SizedBox(width: (c.maxWidth - 20) / 3, child: tile),
          ])),
          const SizedBox(height: 16),
          _Section(
            title: l.sectionHeartRate,
            trailing: l.hrBand(settings.hrLow, settings.hrHigh),
            child: SizedBox(
              height: 170,
              child: TrendChart(
                points: [for (final p in session.heartRate) (p.atMs / 1000, p.bpm)],
                low: settings.hrLow,
                high: settings.hrHigh,
                showAxis: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: l.sectionEcgReview,
            trailing: l.ecgScale,
            child: ecg.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(l.ecgDecryptError('$e')),
              data: (ecg) => ecg == null || ecg.samples.isEmpty
                  ? Text(l.noEcgRecording, style: const TextStyle(color: AppColors.textSecondary))
                  : _review(l, ecg),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: l.sectionEvents,
            trailing: l.tapToSeeEcg,
            child: _Timeline(
              events: session.events,
              // Centre the review strip on the event.
              onTap: (e) => setState(() => _position = e.atMs / 1000 - _stripSeconds / 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _review(AppLocalizations l, SessionEcg ecg) {
    final total = ecg.samples.length / ecg.sampleRate;
    final maxStart = (total - _stripSeconds).clamp(0, double.infinity).toDouble();
    final start = _position.clamp(0, maxStart).toDouble();
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          image: true,
          label: l.stripSemantics(_clock(start), _clock(start + _stripSeconds)),
          child: SizedBox(
            height: 200,
            child: EcgStrip(ecg: ecg, startSample: (start * ecg.sampleRate).round(), seconds: _stripSeconds),
          ),
        ),
      ),
      Slider(
        label: _clock(start),
        semanticFormatterCallback: (v) => l.stripSemantics(_clock(v), _clock(v + _stripSeconds)),
        value: start,
        max: maxStart == 0 ? 1 : maxStart,
        onChanged: maxStart == 0 ? null : (v) => setState(() => _position = v),
      ),
      Text(l.stripRange(_clock(start), _clock(start + _stripSeconds), _clock(total)),
          style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: tabular)),
    ]);
  }

  static String _clock(double seconds) {
    final s = seconds.floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(spacing: 12, runSpacing: 2, alignment: WrapAlignment.spaceBetween, children: [
              Semantics(
                header: true,
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (trailing != null)
                Text(trailing!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events, required this.onTap});
  final List<SessionEvent> events;
  final ValueChanged<SessionEvent> onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Premature beats can number in the hundreds; summarise them instead of listing each.
    final shown = events.where((e) => e.kind != SessionEventKind.heartRate).toList();
    return Column(children: [
      for (var i = 0; i < shown.length; i++)
        InkWell(
          onTap: () => onTap(shown[i]),
          child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 52,
              child: Text(_mmss(shown[i].atMs),
                  style: const TextStyle(color: AppColors.textSecondary, fontFeatures: tabular)),
            ),
            Column(children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(color: _color(shown[i].kind), shape: BoxShape.circle),
              ),
              if (i < shown.length - 1) Expanded(child: Container(width: 2, color: AppColors.outline)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  if (shown[i].kind == SessionEventKind.symptom) ...[
                    const Icon(Icons.person_pin_circle_outlined, size: 18, color: AppColors.info),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      eventText(l, shown[i]),
                      style: TextStyle(
                        fontWeight: shown[i].kind == SessionEventKind.symptom ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                ]),
              ),
            ),
          ]),
          ),
        ),
    ]);
  }

  static Color _color(SessionEventKind kind) => switch (kind) {
        SessionEventKind.alarm => AppColors.alarm,
        SessionEventKind.link => AppColors.warning,
        SessionEventKind.heartRate => AppColors.warning,
        SessionEventKind.symptom => AppColors.info,
        SessionEventKind.info => AppColors.textSecondary,
      };

  static String _mmss(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
