import 'dart:async';

import 'package:device_link/device_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/display.dart';
import '../l10n/l10n.dart';
import '../settings/settings.dart';
import '../theme.dart';
import '../widgets/trend_chart.dart';
import 'ble_connect_sheet.dart';
import 'ecg_buffer.dart';
import 'ecg_view.dart';
import 'monitor_controller.dart';

class MonitorScreen extends ConsumerWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(monitorProvider);
    final controller = ref.read(monitorProvider.notifier);

    ref.listen(monitorProvider.select((s) => s.savedSession), (_, session) {
      if (session == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(l.recordingSaved(_duration(session.duration))),
      ));
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.monitor_heart, color: AppColors.ecg),
          const SizedBox(width: 10),
          Flexible(child: Text(l.appTitle, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          if (state.battery != null) _Battery(percent: state.battery!),
          const SizedBox(width: 4),
          _LinkButton(state: state, onConnect: () => _connect(context, ref), onDisconnect: controller.disconnect),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            for (final banner in _banners(l, state)) ...[banner, const SizedBox(height: 10)],
            _VitalsCard(state: state),
            const SizedBox(height: 12),
            _EcgCard(state: state, buffer: ref.watch(ecgBufferProvider)),
            const SizedBox(height: 12),
            _StatusRow(state: state),
            const SizedBox(height: 20),
            if (state.sessionActive && (state.link == LinkState.connected || state.streaming)) ...[
              if (state.streaming) ...[
                _SymptomButton(count: state.symptoms, onSelected: controller.markSymptom),
                const SizedBox(height: 10),
              ],
              _RecordButton(state: state, onPressed: controller.toggleStreaming),
            ] else if (!state.sessionActive)
              _ConnectHint(onConnect: () => _connect(context, ref)),
            if (ref.watch(demoDeviceProvider) != null) ...[
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.public, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.webDemoNote, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _banners(AppLocalizations l, MonitorState state) => [
        if (state.notMonitoring)
          _Banner(
            color: AppColors.alarm,
            icon: Icons.portable_wifi_off,
            title: l.notMonitoring,
            text: '${state.link == LinkState.connecting ? l.linkReconnecting : l.linkLostBanner}'
                '${state.linkReason != null ? ' · ${state.linkReason}' : ''}',
          ),
        if (state.alarms.contains(DeviceAlarm.leadOff))
          _Banner(color: AppColors.warning, icon: Icons.sensors_off, title: l.electrodeOff, text: l.checkLeads),
        if (state.alarms.contains(DeviceAlarm.lowBattery))
          _Banner(
            color: AppColors.warning,
            icon: Icons.battery_alert,
            title: l.batteryLowTitle,
            text: l.batteryLowText,
          ),
      ];

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    if (settings.connection == DeviceConnectionKind.bluetooth) {
      await showBleConnectSheet(context);
      return;
    }
    if (ref.read(demoDeviceProvider) != null) {
      await ref.read(monitorProvider.notifier).connect('demo', 0);
      return;
    }
    final host = TextEditingController(text: settings.host);
    final port = TextEditingController(text: '${settings.port}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        final l = context.l10n;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.sensors, size: 40, color: AppColors.ecg),
                const SizedBox(height: 12),
                Text(l.connectTitle,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(l.connectSubtitle,
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                TextField(controller: host, decoration: InputDecoration(labelText: l.host)),
                const SizedBox(height: 12),
                TextField(
                  controller: port,
                  decoration: InputDecoration(labelText: l.port),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.link),
                  label: Text(l.connect),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok == true) {
      final newPort = int.tryParse(port.text) ?? settings.port;
      ref.read(settingsProvider.notifier).save(settings.copyWith(host: host.text.trim(), port: newPort));
      await ref.read(monitorProvider.notifier).connect(host.text.trim(), newPort);
    }
  }
}

String _duration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.state, required this.onConnect, required this.onDisconnect});
  final MonitorState state;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (color, label) = switch (state.link) {
      LinkState.connected => (AppColors.ecg, l.linkLive),
      LinkState.connecting => (AppColors.warning, l.linkLinking),
      LinkState.disconnected =>
        state.sessionActive ? (AppColors.alarm, l.linkLost) : (AppColors.textSecondary, l.linkOffline),
    };
    final action = state.sessionActive ? l.disconnect : l.connect;
    return Semantics(
      button: true,
      label: '$label. $action',
      excludeSemantics: true,
      child: Tooltip(
        message: action,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: state.sessionActive ? onDisconnect : onConnect,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  _Dot(color: color, pulsing: state.link == LinkState.connected),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, this.pulsing = false});
  final Color color;
  final bool pulsing;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  // Honour the system "remove animations" setting.
  void _sync() => widget.pulsing && !(WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations)
      ? _controller.repeat(reverse: true)
      : _controller.value = 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
      );
}

class _Battery extends StatelessWidget {
  const _Battery({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    final low = percent <= 15;
    final icon = low ? Icons.battery_alert : (percent > 80 ? Icons.battery_full : Icons.battery_5_bar);
    return Semantics(
      label: context.l10n.batteryLevel(percent),
      excludeSemantics: true,
      child: Row(children: [
        Icon(icon, size: 18, color: low ? AppColors.warning : AppColors.textSecondary),
        Text('$percent%',
            style: TextStyle(
                color: low ? AppColors.warning : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontFeatures: tabular)),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.title, required this.text});
  final Color color;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        // Read out as soon as it appears, even if focus is elsewhere.
        liveRegion: true,
        container: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.black, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                Text(text, style: const TextStyle(color: AppColors.textPrimary)),
              ]),
            ),
          ]),
        ),
      );
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.state});
  final MonitorState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final outOfRange = state.heartRateLow || state.heartRateHigh;
    final color = state.notMonitoring
        ? AppColors.textSecondary
        : outOfRange
            ? AppColors.alarm
            : AppColors.heart;
    final lastBeat = state.trend.isEmpty ? null : state.trend.last.at;
    final t0 = state.trend.isEmpty ? null : state.trend.first.at;

    return Card(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.14), Colors.transparent],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l.heartRateLabel,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              if (state.bpm != null && state.hrSource != null)
                Text(
                  state.hrSource == HeartRateSource.ecg ? l.fromEcg : l.fromSensor,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              if (outOfRange)
                StatusPill(
                  label: state.heartRateHigh ? l.hrHigh(state.limits.high) : l.hrLow(state.limits.low),
                  icon: Icons.warning_rounded,
                  color: AppColors.alarm,
                  filled: true,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // The heart beats with every detected R peak; decorative for screen readers.
            ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(lastBeat),
                tween: Tween(begin: lastBeat == null ? 1.0 : 1.3, end: 1.0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Icon(Icons.favorite, color: color, size: 34),
              ),
            ),
            const SizedBox(width: 10),
            // The big number scales down rather than overflowing with large text.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    state.bpm?.toString() ?? '--',
                    semanticsLabel: state.bpm == null ? l.heartRateUnknown : l.heartRateSemantics(state.bpm!),
                    style: TextStyle(
                      color: color,
                      fontSize: 76,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      fontFeatures: tabular,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExcludeSemantics(
                      child: Text(l.bpm, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 18)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Semantics(
                label: state.trend.isEmpty ? null : l.trendSemantics(state.trendMin!, state.trendMax!),
                child: SizedBox(
                  height: 64,
                  child: TrendChart(
                    points: [for (final p in state.trend) (p.at.difference(t0!).inMilliseconds / 1000, p.bpm)],
                    low: state.limits.low,
                    high: state.limits.high,
                    // Grow from one minute up to the full window, so a new recording is not squeezed into a corner.
                    spanSeconds: state.trend.isEmpty
                        ? 60
                        : (state.trend.last.at.difference(t0!).inSeconds.toDouble())
                            .clamp(60, MonitorController.trendWindow.inSeconds.toDouble()),
                    color: color,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 18, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _MiniStat(l.statMin, state.trendMin),
            _MiniStat(l.statAvg, state.trendAvg),
            _MiniStat(l.statMax, state.trendMax),
            Text(l.last5min, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          TextSpan(
              text: value?.toString() ?? '--',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: tabular)),
        ]),
      );
}

class _EcgCard extends StatelessWidget {
  const _EcgCard({required this.state, required this.buffer});
  final MonitorState state;
  final EcgBuffer buffer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
          child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(l.ecgLabel,
                style: const TextStyle(color: AppColors.ecg, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            Text(l.ecgScale, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            if (state.recordingSince != null) _RecIndicator(since: state.recordingSince!),
          ]),
        ),
        SizedBox(
          height: 230,
          child: state.heartRateOnly
              ? const _NoEcg()
              : Semantics(
                  image: true,
                  label: state.notMonitoring ? l.ecgSemanticsDimmed : l.ecgSemantics,
                  child: EcgView(buffer: buffer, dimmed: state.notMonitoring),
                ),
        ),
      ]),
    );
  }
}

class _NoEcg extends StatelessWidget {
  const _NoEcg();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bluetooth_connected, size: 36, color: AppColors.info),
          const SizedBox(height: 10),
          Text(l.noEcgTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            l.noEcgText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ]),
      ),
    );
  }
}

class _RecIndicator extends StatefulWidget {
  const _RecIndicator({required this.since});
  final DateTime since;

  @override
  State<_RecIndicator> createState() => _RecIndicatorState();
}

class _RecIndicatorState extends State<_RecIndicator> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _duration(DateTime.now().difference(widget.since));
    return Semantics(
      label: context.l10n.recSemantics(elapsed),
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const _Dot(color: AppColors.alarm, pulsing: true),
        const SizedBox(width: 6),
        Text(
          context.l10n.rec(elapsed),
          style: const TextStyle(color: AppColors.alarm, fontWeight: FontWeight.w800, fontFeatures: tabular),
        ),
      ]),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});
  final MonitorState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stats = state.stats;
    final device = state.device;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      StatusPill(
        label: state.irregular ? l.rrIrregular : l.rrRegular,
        icon: Icons.timeline,
        color: state.irregular ? AppColors.warning : AppColors.ecg,
      ),
      StatusPill(
        label: l.prematureBeats(state.ectopicBeats),
        icon: Icons.bolt,
        color: state.ectopicBeats > 0 ? AppColors.warning : AppColors.textSecondary,
      ),
      if (stats != null)
        StatusPill(
          label: stats.lostSamples == 0 ? l.noDataLost : l.samplesLost(stats.lostSamples),
          icon: stats.lostSamples == 0 ? Icons.verified : Icons.signal_cellular_connected_no_internet_4_bar,
          color: stats.lostSamples == 0 ? AppColors.info : AppColors.warning,
        ),
      if (device != null)
        StatusPill(
          label: device.sampleRate > 0 ? '${device.deviceId} · ${device.sampleRate} Hz' : device.deviceId,
          icon: Icons.memory,
        ),
    ]);
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.state, required this.onPressed});
  final MonitorState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: state.streaming ? AppColors.surfaceHigh : AppColors.ecg,
          foregroundColor: state.streaming ? AppColors.alarm : Colors.black,
          side: state.streaming ? const BorderSide(color: AppColors.alarm) : null,
        ),
        onPressed: onPressed,
        icon: Icon(state.streaming ? Icons.stop_rounded : Icons.fiber_manual_record),
        label: Text(state.streaming ? context.l10n.stopRecording : context.l10n.startRecording),
      );
}

/// Holter-style symptom diary: the patient taps what they feel and it is
/// pinned to that moment of the ECG. Symptoms are stored by their English key.
class _SymptomButton extends StatelessWidget {
  const _SymptomButton({required this.count, required this.onSelected});
  final int count;
  final ValueChanged<String> onSelected;

  static const symptoms = [
    (Icons.graphic_eq, 'Palpitations'),
    (Icons.blur_on, 'Dizziness'),
    (Icons.heart_broken_outlined, 'Chest pain'),
    (Icons.air, 'Shortness of breath'),
    (Icons.battery_1_bar, 'Fatigue'),
    (Icons.directions_run, 'Exercise'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.info,
        side: const BorderSide(color: AppColors.info),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: const Icon(Icons.add_reaction_outlined),
      label: Text(count == 0 ? l.markSymptom : l.markSymptomCount(count)),
      onPressed: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l.symptomQuestion, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(l.symptomHint,
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  for (final (icon, key) in symptoms)
                    SizedBox(
                      width: 104,
                      child: Material(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.pop(context, key),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 96),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(icon, color: AppColors.info, size: 30),
                                const SizedBox(height: 8),
                                Text(symptomName(l, key),
                                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        );
        if (picked != null) {
          onSelected(picked);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(l.symptomMarked(symptomName(l, picked))),
            ));
          }
        }
      },
    );
  }
}

class _ConnectHint extends StatelessWidget {
  const _ConnectHint({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onConnect,
        icon: const Icon(Icons.sensors),
        label: Text(context.l10n.connectDevice),
      );
}
