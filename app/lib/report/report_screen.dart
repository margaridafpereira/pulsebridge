import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../l10n/l10n.dart';
import '../monitor/monitor_controller.dart' show clockProvider;
import '../profile/profile.dart';
import '../sessions/session.dart';
import '../sessions/sessions_provider.dart';
import '../settings/settings.dart';
import 'report.dart';

/// Preview of the PDF report for one session, with share and print.
/// The PDF only exists once the user opens this screen (SRS-022).
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stamp = session.start.toIso8601String().substring(0, 16).replaceAll(RegExp('[:T]'), '-');
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reportTitle)),
      body: PdfPreview(
        build: (_) async {
          final input = ReportInput(
            session: session,
            ecg: await ref.read(sessionRepositoryProvider).loadEcg(session),
            profile: await ref.read(profileProvider.future),
            settings: await ref.read(settingsProvider.future),
            generatedAt: ref.read(clockProvider)(),
          );
          return buildReport(input, l10n, theme: await loadReportTheme());
        },
        pdfFileName: 'pulsebridge-ecg-$stamp.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const CircularProgressIndicator(),
        pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white),
        previewPageMargin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        scrollViewDecoration: const BoxDecoration(color: Color(0xFF070B0F)),
      ),
    );
  }
}
