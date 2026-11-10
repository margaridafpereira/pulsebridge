import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../monitor/monitor_controller.dart' show clockProvider;
import '../theme.dart';
import 'clinical_lock.dart';

/// Shows [child] only while the clinical area is unlocked. Otherwise asks for
/// a PIN to be created, or for the PIN / fingerprint.
class ClinicalGate extends ConsumerWidget {
  const ClinicalGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(clinicalLockProvider);
    return lock.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(context.l10n.lockError('$e')))),
      data: (s) {
        if (!s.configured) return const _CreatePin();
        if (!s.unlocked) return _LockScreen(state: s);
        return child;
      },
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({required this.state});
  final ClinicalLockState state;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  String? _message;

  @override
  void initState() {
    super.initState();
    // Offer the fingerprint straight away; the keypad stays as the fallback.
    if (widget.state.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  Future<void> _biometric() async {
    if (!mounted) return;
    final l = context.l10n;
    final ok = await ref.read(clinicalLockProvider.notifier).unlockWithBiometrics(reason: l.biometricReason);
    if (!ok && mounted) setState(() => _message = l.fingerprintFailed);
  }

  Future<String?> _submit(String pin) async {
    final l = context.l10n;
    final result = await ref.read(clinicalLockProvider.notifier).unlock(pin);
    return switch (result) {
      Unlocked() => null,
      WrongPin(:final attemptsLeft) => l.wrongPinAttempts(attemptsLeft),
      LockedOut() => l.tooManyPins,
    };
  }

  @override
  Widget build(BuildContext context) => _PinScaffold(
        icon: Icons.lock_outline,
        title: context.l10n.lockedTitle,
        subtitle: context.l10n.lockedSubtitle,
        message: _message,
        lockedUntil: widget.state.lockedUntil,
        onCompleted: _submit,
        onBiometric: widget.state.biometricEnabled ? _biometric : null,
      );
}

class _CreatePin extends ConsumerStatefulWidget {
  const _CreatePin();

  @override
  ConsumerState<_CreatePin> createState() => _CreatePinState();
}

class _CreatePinState extends ConsumerState<_CreatePin> {
  String? _first;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _PinScaffold(
        key: ValueKey(_first == null),
        icon: Icons.shield_outlined,
        title: _first == null ? l.protectTitle : l.confirmPin,
        subtitle: _first == null ? l.protectSubtitle : l.confirmPinSubtitle,
        onCompleted: (pin) async {
          if (_first == null) {
            setState(() => _first = pin);
            return null;
          }
          if (pin != _first) {
            setState(() => _first = null);
            return l.pinMismatch;
          }
          await ref.read(clinicalLockProvider.notifier).setPin(pin);
          return null;
        },
      );
  }
}

/// Change the PIN: current, new, confirm. Pushed from Settings.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  int _step = 0;
  String? _new;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lock = ref.watch(clinicalLockProvider).value;
    final controller = ref.read(clinicalLockProvider.notifier);
    return _PinScaffold(
      key: ValueKey(_step),
      icon: Icons.password,
      title: [l.currentPin, l.newPin, l.confirmNewPin][_step],
      subtitle: [l.currentPinSubtitle, l.newPinSubtitle, l.confirmNewPinSubtitle][_step],
      lockedUntil: _step == 0 ? lock?.lockedUntil : null,
      showBack: true,
      onCompleted: (pin) async {
        switch (_step) {
          case 0:
            final result = await controller.verify(pin);
            if (result is! Unlocked) {
              return result is LockedOut ? l.tooManyPins : l.wrongPin;
            }
            setState(() => _step = 1);
          case 1:
            setState(() {
              _new = pin;
              _step = 2;
            });
          case 2:
            if (pin != _new) {
              setState(() => _step = 1);
              return l.newPinMismatch;
            }
            await controller.setPin(pin);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.pinChanged)));
              Navigator.pop(context);
            }
        }
        return null;
      },
    );
  }
}

/// Title, PIN dots and keypad. [onCompleted] gets the 6 digits and returns an
/// error to show, or null.
class _PinScaffold extends ConsumerStatefulWidget {
  const _PinScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onCompleted,
    this.message,
    this.lockedUntil,
    this.onBiometric,
    this.showBack = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? message;
  final DateTime? lockedUntil;
  final Future<String?> Function(String pin) onCompleted;
  final VoidCallback? onBiometric;
  final bool showBack;

  @override
  ConsumerState<_PinScaffold> createState() => _PinScaffoldState();
}

class _PinScaffoldState extends ConsumerState<_PinScaffold> {
  String _pin = '';
  String? _error;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Redraw the lockout countdown every second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.lockedUntil != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration? get _lockLeft {
    final until = widget.lockedUntil;
    if (until == null) return null;
    final left = until.difference(ref.read(clockProvider)());
    return left.isNegative ? null : left;
  }

  Future<void> _press(String digit) async {
    if (_busy || _lockLeft != null || _pin.length >= ClinicalLockController.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length < ClinicalLockController.pinLength) return;
    setState(() => _busy = true);
    final error = await widget.onCompleted(_pin);
    if (!mounted) return;
    if (error != null) HapticFeedback.heavyImpact();
    setState(() {
      _pin = '';
      _error = error;
      _busy = false;
    });
  }

  void _delete() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lockLeft = _lockLeft;
    final error = lockLeft != null
        ? l.tryAgainIn('${lockLeft.inMinutes}:${(lockLeft.inSeconds % 60).toString().padLeft(2, '0')}')
        : _error ?? widget.message;

    return Scaffold(
      appBar: widget.showBack ? AppBar() : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.info.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                    ),
                    child: Icon(widget.icon, size: 34, color: AppColors.info),
                  ),
                  const SizedBox(height: 20),
                  Text(widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(widget.subtitle,
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 28),
                  Semantics(
                    liveRegion: true,
                    label: l.pinDigits(_pin.length),
                    excludeSemantics: true,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < ClinicalLockController.pinLength; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length ? AppColors.ecg : Colors.transparent,
                          border: Border.all(
                            color: error != null && _pin.isEmpty ? AppColors.alarm : AppColors.textSecondary,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ]),
                  ),
                  SizedBox(
                    height: 48,
                    child: Center(
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : error == null
                              ? null
                              : Text(error,
                                  key: const Key('pin-message'),
                                  semanticsLabel: error,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.alarm, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  _Keypad(
                    enabled: lockLeft == null && !_busy,
                    onDigit: _press,
                    onDelete: _delete,
                    onBiometric: widget.onBiometric,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.enabled, required this.onDigit, required this.onDelete, this.onBiometric});
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => _Key(
          onTap: enabled ? () => onDigit(d) : null,
          child: Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
        );
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          onBiometric == null
              ? const SizedBox(width: 96, height: 76)
              : _Key(
                  tooltip: context.l10n.useFingerprint,
                  onTap: enabled ? onBiometric : null,
                  child: const Icon(Icons.fingerprint, size: 34, color: AppColors.ecg),
                ),
          key('0'),
          _Key(
            tooltip: context.l10n.deleteDigit,
            onTap: enabled ? onDelete : null,
            child: const Icon(Icons.backspace_outlined, size: 26),
          ),
        ]),
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.child, this.onTap, this.tooltip});
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final key = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 72, height: 64, child: Center(child: child)),
        ),
      ),
    );
    return tooltip == null ? key : Tooltip(message: tooltip!, child: key);
  }
}
