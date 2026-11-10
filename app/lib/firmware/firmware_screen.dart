import 'package:device_link/device_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../monitor/monitor_controller.dart';
import '../theme.dart';

/// The firmware shipped with the app.
const availableFirmware = '1.1.0';
const _asset = 'assets/firmware/pulsebridge-$availableFirmware.bin';

/// Compares dotted versions numerically (1.10.0 > 1.9.0).
int compareVersions(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final d = (i < pa.length ? pa[i] : 0) - (i < pb.length ? pb[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

class FirmwareScreen extends ConsumerWidget {
  const FirmwareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(monitorProvider);
    final controller = ref.read(monitorProvider.notifier);
    final device = state.device;
    final current = device?.firmware ?? '—';
    final connected = state.link == LinkState.connected && device != null && !state.heartRateOnly;
    final progress = state.firmware;
    final running = state.updatingFirmware;
    final upToDate = device != null && compareVersions(device.firmware, availableFirmware) >= 0;

    String? blocker;
    if (!connected && !running) blocker = l.fwConnectFirst;
    if (state.streaming) blocker = l.fwStopRecording;

    return Scaffold(
      appBar: AppBar(title: Text(l.firmwareTitle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _Version(label: l.fwInstalled, value: current)),
                const ExcludeSemantics(child: Icon(Icons.arrow_forward, color: AppColors.textSecondary)),
                Expanded(
                  child: _Version(label: l.fwAvailable, value: availableFirmware, color: AppColors.ecg),
                ),
              ]),
              const SizedBox(height: 14),
              Text(l.fwChanges, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (progress != null) _ProgressCard(progress: progress),
        if (blocker != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(liveRegion: true, child: Text(blocker, style: const TextStyle(color: AppColors.warning))),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        if (running)
          OutlinedButton.icon(
            icon: const Icon(Icons.close),
            label: Text(l.fwCancel),
            onPressed: controller.cancelFirmware,
          )
        else
          FilledButton.icon(
            icon: const Icon(Icons.system_update_alt),
            label: Text(upToDate ? l.fwUpToDate : l.fwInstall(availableFirmware)),
            onPressed: blocker != null || upToDate
                ? null
                : () async {
                    final data = await rootBundle.load(_asset);
                    await controller.updateFirmware(data.buffer.asUint8List(), availableFirmware);
                  },
          ),
        const SizedBox(height: 20),
        const _HowItWorks(),
      ]),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version({required this.label, required this.value, this.color = AppColors.textPrimary});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Column(children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color, fontFeatures: tabular)),
      ]),
      );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final FirmwareProgress progress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, color, title) = switch (progress.stage) {
      FirmwareStage.sending => (Icons.upload, AppColors.info, l.fwSending),
      FirmwareStage.waitingForLink => (Icons.link_off, AppColors.warning, l.fwWaitingLink),
      FirmwareStage.verifying => (Icons.verified_outlined, AppColors.info, l.fwVerifying),
      FirmwareStage.restarting => (Icons.restart_alt, AppColors.info, l.fwRestarting),
      FirmwareStage.done => (Icons.check_circle, AppColors.ecg, l.fwDone),
      FirmwareStage.failed => (Icons.error_outline, AppColors.alarm, l.fwFailed),
      FirmwareStage.cancelled => (Icons.cancel_outlined, AppColors.textSecondary, l.fwCancelled),
    };
    String kb(int b) => (b / 1024).toStringAsFixed(0);
    final active = !progress.finished;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            Text('${(progress.fraction * 100).round()} %',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontFeatures: tabular)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.stage == FirmwareStage.restarting || progress.stage == FirmwareStage.verifying
                  ? null
                  : progress.fraction,
              minHeight: 10,
              color: color,
              backgroundColor: AppColors.outline,
              semanticsLabel: l.fwProgressSemantics,
              semanticsValue: l.percentValue((progress.fraction * 100).round()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              l.fwProgressKb(kb(progress.sent), kb(progress.total)),
              if (progress.detail != null) progress.detail!,
            ].join(' · '),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (active) ...[
            const SizedBox(height: 14),
            _Steps(stage: progress.stage),
          ],
          if (progress.stage == FirmwareStage.failed)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(l.fwKeptOld, style: const TextStyle(fontSize: 13)),
            ),
        ]),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.stage});
  final FirmwareStage stage;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [l.fwStepSend, l.fwStepVerify, l.fwStepRestart, l.fwStepConfirm];
    final current = switch (stage) {
      FirmwareStage.sending || FirmwareStage.waitingForLink => 0,
      FirmwareStage.verifying => 1,
      FirmwareStage.restarting => 2,
      _ => 3,
    };
    return Row(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Expanded(
          child: Column(children: [
            Icon(
              i < current ? Icons.check_circle : i == current ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: i <= current ? AppColors.ecg : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(steps[i], style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ],
    ]);
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(l.fwHowTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          _Point(Icons.view_module_outlined, l.fwHow1),
          _Point(Icons.sync, l.fwHow2),
          _Point(Icons.verified_user_outlined, l.fwHow3),
          _Point(Icons.undo, l.fwHow4),
          _Point(Icons.fact_check_outlined, l.fwHow5),
        ]),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
