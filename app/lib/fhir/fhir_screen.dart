import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../monitor/monitor_controller.dart' show clockProvider;
import '../profile/profile.dart';
import '../sessions/session.dart';
import '../sessions/sessions_provider.dart';
import '../settings/settings.dart';
import '../theme.dart';
import 'fhir_export.dart';

final _bundleProvider = FutureProvider.autoDispose.family<Map<String, Object?>, Session>((ref, session) async {
  return FhirExport().bundle(
    session: session,
    ecg: await ref.read(sessionRepositoryProvider).loadEcg(session),
    profile: await ref.read(profileProvider.future),
    generatedAt: ref.read(clockProvider)(),
  );
});

/// Shows what the FHIR export contains, then shares it as a file or sends it
/// to the FHIR server set in Settings. Nothing leaves the phone until the user
/// taps one of the two.
class FhirScreen extends ConsumerStatefulWidget {
  const FhirScreen({super.key, required this.session});
  final Session session;

  @override
  ConsumerState<FhirScreen> createState() => _FhirScreenState();
}

class _FhirScreenState extends ConsumerState<FhirScreen> {
  bool _sending = false;
  FhirSendResult? _result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bundle = ref.watch(_bundleProvider(widget.session));
    final server = ref.watch(settingsProvider).value?.fhirServer ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l.fhirExport)),
      body: bundle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.fhirBuildError('$e'))),
        data: (b) {
          final json = const JsonEncoder.withIndent('  ').convert(b);
          final entries = (b['entry']! as List).cast<Map<String, Object?>>();
          final counts = <String, int>{};
          for (final e in entries) {
            final type = (e['resource']! as Map)['resourceType']! as String;
            counts[type] = (counts[type] ?? 0) + 1;
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.local_hospital_outlined, color: AppColors.info),
                    SizedBox(width: 8),
                    Text('HL7 FHIR R4 · transaction Bundle', style: TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 12),
                  for (final MapEntry(:key, :value) in counts.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Text(key),
                        const Spacer(),
                        Text('$value', style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: tabular)),
                      ]),
                    ),
                  const Divider(),
                  Row(children: [
                    Text(l.size, style: const TextStyle(color: AppColors.textSecondary)),
                    const Spacer(),
                    Text('${(utf8.encode(json).length / 1024).toStringAsFixed(0)} KB'),
                  ]),
                  const SizedBox(height: 8),
                  Text(l.fhirCodes, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.share),
              label: Text(l.shareFile),
              onPressed: () => SharePlus.instance.share(ShareParams(
                files: [
                  XFile.fromData(Uint8List.fromList(utf8.encode(json)), mimeType: 'application/fhir+json'),
                ],
                fileNameOverrides: ['pulsebridge-${widget.session.id}.fhir.json'],
                subject: l.fhirShareSubject,
              )),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(server.isEmpty ? l.fhirSendNoServer : l.fhirSendTo(server)),
              onPressed: server.isEmpty || _sending ? null : () => _send(Uri.parse(server), b),
            ),
            if (_result != null) _ResultCard(result: _result!),
            const SizedBox(height: 16),
            Text(l.preview, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(
                // The ECG data string is long; the preview shows the structure.
                json.length > 6000 ? '${json.substring(0, 6000)}\n…' : json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _send(Uri server, Map<String, Object?> bundle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = context.l10n;
        return AlertDialog(
          title: Text(l.fhirSendTitle),
          content: Text(l.fhirSendText('$server')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.send)),
          ],
        );
      },
    );
    if (ok != true) return;
    setState(() {
      _sending = true;
      _result = null;
    });
    final result = await sendBundle(server, bundle);
    if (mounted) {
      setState(() {
        _sending = false;
        _result = result;
      });
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final FhirSendResult result;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(result.ok ? Icons.check_circle : Icons.error_outline,
                  color: result.ok ? AppColors.ecg : AppColors.alarm),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.ok
                      ? context.l10n.fhirAccepted(result.created.length)
                      : context.l10n.fhirNotSent(result.error ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            for (final c in result.created.take(12))
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 32),
                child: Text(c, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
          ]),
        ),
      );
}
