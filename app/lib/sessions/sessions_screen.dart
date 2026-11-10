import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/display.dart';
import '../l10n/l10n.dart';

import '../clinical/clinical_lock.dart';
import '../settings/settings.dart';
import '../theme.dart';
import '../widgets/trend_chart.dart';
import 'session.dart';
import 'session_detail_screen.dart';
import 'sessions_provider.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sessions = ref.watch(sessionsProvider);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabRecordings),
        actions: [
          IconButton(
            tooltip: l.lock,
            icon: const Icon(Icons.lock_open),
            onPressed: () => ref.read(clinicalLockProvider.notifier).lock(),
          ),
        ],
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Empty(icon: Icons.error_outline, title: l.recordingsError, text: '$e'),
        data: (list) => list.isEmpty
            ? _Empty(icon: Icons.monitor_heart_outlined, title: l.noRecordings, text: l.noRecordingsText)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(sessionsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => i == 0
                      ? const _EncryptionNote()
                      : _SessionCard(session: list[i - 1], settings: settings),
                ),
              ),
      ),
    );
  }
}

class _EncryptionNote extends StatelessWidget {
  const _EncryptionNote();

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.lock, size: 14, color: AppColors.info),
        const SizedBox(width: 6),
        Expanded(
          child: Text(context.l10n.encryptionNote,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
      ]);
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.settings});
  final Session session;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hasAlarms = session.alarmCount > 0;
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.alarm, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_outline, color: Colors.black),
      ),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) async {
        await ref.read(sessionRepositoryProvider).delete(session);
        ref.invalidate(sessionsProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: session),
          )),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasAlarms ? AppColors.warning : AppColors.ecg).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.monitor_heart, color: hasAlarms ? AppColors.warning : AppColors.ecg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(formatDate(session.start),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('${formatDuration(session.duration)} · ${session.deviceId}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(session.avgBpm?.toString() ?? '--',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ecg, fontFeatures: tabular)),
                  Text(l.avgBpm, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: TrendChart(
                  points: [for (final p in session.heartRate) (p.atMs / 1000, p.bpm)],
                  low: settings.hrLow,
                  high: settings.hrHigh,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (session.minBpm != null)
                  StatusPill(label: l.bpmRange(session.minBpm!, session.maxBpm!), icon: Icons.favorite),
                if (session.ectopicBeats > 0)
                  StatusPill(label: l.prematureShort(session.ectopicBeats), icon: Icons.bolt, color: AppColors.warning),
                if (hasAlarms)
                  StatusPill(
                      label: l.alarmsCount(session.alarmCount), icon: Icons.notifications_active, color: AppColors.alarm),
                if (session.lostSamples > 0)
                  StatusPill(
                      label: l.lostPercent(session.lostPercent.toStringAsFixed(1)),
                      icon: Icons.link_off,
                      color: AppColors.warning),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.ecg.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: AppColors.ecg),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
}

Future<bool?> confirmDelete(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (context) {
        final l = context.l10n;
        return AlertDialog(
          title: Text(l.deleteTitle),
          content: Text(l.deleteText),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.alarm, minimumSize: const Size(88, 48)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.delete),
            ),
          ],
        );
      },
    );

/// In the app's language (Intl.defaultLocale is set from the app locale).
String formatDate(DateTime d) => formatDateFor(Intl.getCurrentLocale(), d);

String formatDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}
