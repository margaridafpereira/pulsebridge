import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clinical/clinical_gate.dart';
import '../clinical/clinical_lock.dart';
import '../firmware/firmware_screen.dart';
import '../l10n/l10n.dart';
import '../monitor/monitor_controller.dart';
import '../theme.dart';
import 'settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final controller = ref.read(settingsProvider.notifier);
    const note = TextStyle(color: AppColors.textSecondary, fontSize: 13);

    return Scaffold(
      appBar: AppBar(title: Text(l.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Group(
            icon: Icons.favorite,
            title: l.hrLimitsTitle,
            children: [
              MergeSemantics(
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(alignment: WrapAlignment.center, spacing: 32, runSpacing: 8, children: [
                    _Limit(label: l.limitLow, value: settings.hrLow),
                    _Limit(label: l.limitHigh, value: settings.hrHigh),
                  ]),
                ),
              ),
              Semantics(
                label: l.hrLimitsSemantics(settings.hrLow, settings.hrHigh),
                child: RangeSlider(
                  values: RangeValues(settings.hrLow.toDouble(), settings.hrHigh.toDouble()),
                  min: 30,
                  max: 200,
                  divisions: 34,
                  labels: RangeLabels('${settings.hrLow}', '${settings.hrHigh}'),
                  onChanged: (v) => controller.save(settings.copyWith(hrLow: v.start.round(), hrHigh: v.end.round())),
                ),
              ),
              Text(l.hrLimitsText, style: note),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            icon: Icons.sensors,
            title: l.deviceTitle,
            children: [
              // Chips rather than a segmented button: they wrap with large text.
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (kind, icon, label) in [
                  (DeviceConnectionKind.simulator, Icons.lan_outlined, l.ecgSimulator),
                  (DeviceConnectionKind.bluetooth, Icons.bluetooth, l.bluetooth),
                ])
                  ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    selected: settings.connection == kind,
                    onSelected: (_) => controller.save(settings.copyWith(connection: kind)),
                  ),
              ]),
              if (settings.connection == DeviceConnectionKind.simulator) ...[
                _Row(label: l.host, value: settings.host),
                _Row(label: l.port, value: '${settings.port}'),
                Text(l.simulatorText, style: note),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.memory),
                  title: Text(l.firmwareTitle),
                  subtitle: Text(
                    l.firmwareSubtitle(ref.watch(monitorProvider).device?.firmware ?? '—', availableFirmware),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const FirmwareScreen()),
                  ),
                ),
              ] else ...[
                _Row(label: l.sensor, value: settings.bleName ?? settings.bleAddress ?? l.noneYet),
                if (settings.bleAddress != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          controller.save(settings.copyWith(bleAddress: () => null, bleName: () => null)),
                      child: Text(l.forgetSensor),
                    ),
                  ),
                Text(l.bluetoothText, style: note),
              ],
              Text(l.typeAppliesNext, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            icon: Icons.translate,
            title: l.language,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                // Language names are written in their own language.
                for (final (code, label) in [('system', l.languageSystem), ('en', 'English'), ('pt', 'Português')])
                  ChoiceChip(
                    label: Text(label),
                    selected: settings.language == code,
                    onSelected: (_) => controller.save(settings.copyWith(language: code)),
                  ),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            icon: Icons.local_hospital_outlined,
            title: l.fhirExport,
            children: [
              _Row(label: l.server, value: settings.fhirServer.isEmpty ? l.none : settings.fhirServer),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: Text(l.setServer),
                  onPressed: () async {
                    final value = await _askServer(context, settings.fhirServer);
                    if (value != null) await controller.save(settings.copyWith(fhirServer: value));
                  },
                ),
              ),
              Text(l.fhirSettingsText, style: note),
            ],
          ),
          const SizedBox(height: 12),
          const _ClinicianAccess(),
          const SizedBox(height: 12),
          _Group(
            icon: Icons.lock,
            title: l.privacyTitle,
            children: [
              _Row(label: l.storage, value: 'AES-256-GCM'),
              _Row(label: l.key, value: 'Android Keystore'),
              Text(l.privacyText, style: note),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            icon: Icons.info_outline,
            title: l.aboutTitle,
            children: [
              _Row(label: l.version, value: '1.1.0'),
              Text(l.aboutText, style: note),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> _askServer(BuildContext context, String current) {
  final text = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l = context.l10n;
      return AlertDialog(
        title: Text(l.fhirServerTitle),
        content: TextField(
          controller: text,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: l.baseUrl, hintText: 'https://hapi.fhir.org/baseR4'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(l.clear)),
          FilledButton(
            onPressed: () {
              final url = text.text.trim();
              final uri = Uri.tryParse(url);
              if (url.isNotEmpty && (uri == null || uri.scheme != 'https' || uri.host.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.useHttps)));
                return;
              }
              Navigator.pop(context, url);
            },
            child: Text(l.save),
          ),
        ],
      );
    },
  );
}

class _ClinicianAccess extends ConsumerWidget {
  const _ClinicianAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lock = ref.watch(clinicalLockProvider).value;
    final biometrics = ref.watch(biometricAvailableProvider).value ?? false;
    final controller = ref.read(clinicalLockProvider.notifier);
    if (lock == null) return const SizedBox.shrink();
    const note = TextStyle(color: AppColors.textSecondary, fontSize: 13);

    if (!lock.configured) {
      return _Group(icon: Icons.shield_outlined, title: l.clinicianAccess, children: [
        Text(l.createPinHint, style: note),
      ]);
    }

    return _Group(
      icon: Icons.shield_outlined,
      title: l.clinicianAccess,
      children: [
        _Row(label: l.tabRecordings, value: lock.unlocked ? l.unlocked : l.locked),
        // Changing how the area opens needs it open, so a passer-by cannot
        // add their fingerprint path.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.fingerprintUnlock),
          subtitle: Text(
            !biometrics
                ? l.noFingerprint
                : lock.unlocked
                    ? l.pinFallback
                    : l.unlockToChange,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          value: lock.biometricEnabled,
          onChanged: biometrics && lock.unlocked
              ? (v) async {
                  final ok = await controller.setBiometricEnabled(v, reason: l.biometricEnableReason);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.fingerprintNotConfirmed)));
                  }
                }
              : null,
        ),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.password, size: 18),
            label: Text(l.changePin),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const ChangePinScreen()),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.lock_outline, size: 18),
            label: Text(l.lockNow),
            onPressed: lock.unlocked ? controller.lock : null,
          ),
        ]),
        Text(l.lockInfo, style: note),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 20, color: AppColors.ecg),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            for (final child in children) ...[child, const SizedBox(height: 8)],
          ]),
        ),
      );
}

class _Limit extends StatelessWidget {
  const _Limit({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        Text('$value',
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.alarm, fontFeatures: tabular)),
        Text(context.l10n.bpm, style: const TextStyle(color: AppColors.textSecondary)),
      ]);
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: SizedBox(
          width: double.infinity,
          child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
