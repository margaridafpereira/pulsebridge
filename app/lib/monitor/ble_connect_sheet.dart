import 'package:device_link/device_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../settings/settings.dart';
import '../theme.dart';
import 'monitor_controller.dart';

/// Finds Bluetooth heart-rate sensors and connects to the one picked.
/// Returns true once a connection was started.
Future<bool?> showBleConnectSheet(BuildContext context) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _BleConnectSheet(),
    );

class _BleConnectSheet extends ConsumerStatefulWidget {
  const _BleConnectSheet();

  @override
  ConsumerState<_BleConnectSheet> createState() => _BleConnectSheetState();
}

class _BleConnectSheetState extends ConsumerState<_BleConnectSheet> {
  bool _scanning = true;
  String? _problem;
  List<BleDevice>? _found;

  @override
  void initState() {
    super.initState();
    // After the first frame: the scan reads localized strings from the context.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    if (ref.read(demoDeviceProvider) != null) {
      // Web Bluetooth: the browser lists the sensors itself.
      final bt = await ref.read(deviceLinkProvider).bluetoothState();
      if (mounted) {
        setState(() {
          _scanning = false;
          _found = const [];
          _problem = bt.supported ? null : context.l10n.bleWebUnsupported;
        });
      }
      return;
    }
    final link = ref.read(deviceLinkProvider);
    final l = context.l10n;
    setState(() {
      _scanning = true;
      _problem = null;
    });
    try {
      var bt = await link.bluetoothState();
      if (!bt.supported) return _fail(l.bleNoBluetooth);
      if (!bt.permitted && !await link.requestBluetoothPermissions()) {
        return _fail(l.blePermission);
      }
      bt = await link.bluetoothState();
      if (!bt.enabled) return _fail(l.bleOff);
      final found = await link.scanBle();
      if (mounted) setState(() => _found = found);
    } on Exception catch (e) {
      _fail(l.bleScanFailed('$e'));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _problem = message);
  }

  Future<void> _connect(String address, String? name) async {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    await ref
        .read(settingsProvider.notifier)
        .save(settings.copyWith(bleAddress: () => address, bleName: () => name));
    await ref.read(monitorProvider.notifier).connectBle(address);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final last = settings.bleAddress;
    final found = _found ?? const <BleDevice>[];
    final web = ref.watch(demoDeviceProvider) != null;
    if (web) return _webPicker(l);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.bluetooth_searching, size: 40, color: AppColors.info),
            const SizedBox(height: 12),
            Text(l.bleTitle,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.bleSubtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            if (last != null)
              _DeviceTile(
                icon: Icons.history,
                title: settings.bleName ?? last,
                subtitle: l.bleLastUsed(last),
                onTap: () => _connect(last, settings.bleName),
              ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_problem!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.warning)),
                ),
              ),
            if (_scanning)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l.bleSearching, style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              )
            else if (_found != null && found.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l.bleNoneFound,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final d in found)
                  if (d.address != last)
                    _DeviceTile(
                      icon: d.heartRate ? Icons.favorite : Icons.bluetooth,
                      iconColor: d.heartRate ? AppColors.alarm : AppColors.textSecondary,
                      title: d.name ?? l.bleUnnamed,
                      subtitle: d.heartRate ? l.bleHrSensor(d.address) : d.address,
                      trailing: _SignalBars(rssi: d.rssi),
                      onTap: () => _connect(d.address, d.name),
                    ),
              ]),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _scanning ? null : _scan,
              icon: const Icon(Icons.refresh),
              label: Text(l.bleScanAgain),
            ),
          ]),
        ),
      ),
    );
  }
}

extension on _BleConnectSheetState {
  Widget _webPicker(AppLocalizations l) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.bluetooth_searching, size: 40, color: AppColors.info),
            const SizedBox(height: 12),
            Text(l.bleTitle,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.bleSubtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Text(_problem ?? l.bleWebHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: _problem != null ? AppColors.warning : AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.bluetooth),
              label: Text(l.bleChoose),
              // Straight from the tap: the browser only opens its picker on a user gesture.
              onPressed: _scanning || _problem != null
                  ? null
                  : () {
                      ref.read(monitorProvider.notifier).connectBle('web');
                      Navigator.pop(context, true);
                    },
            ),
          ]),
        ),
      );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.info,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: AppColors.background,
        child: ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          trailing: trailing,
          onTap: onTap,
        ),
      );
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rssi});
  final int rssi;

  @override
  Widget build(BuildContext context) {
    final bars = rssi >= -60 ? 4 : rssi >= -70 ? 3 : rssi >= -80 ? 2 : 1;
    return Semantics(
      label: context.l10n.bleSignal(bars),
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 1; i <= 4; i++)
          Container(
            width: 4,
            height: 4.0 + i * 4,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: i <= bars ? AppColors.ecg : AppColors.outline,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ]),
    );
  }
}
