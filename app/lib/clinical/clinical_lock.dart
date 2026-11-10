import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../monitor/monitor_controller.dart' show clockProvider;
import '../settings/settings.dart';

/// PBKDF2-HMAC-SHA256 (RFC 8018), one 32-byte block.
Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final out = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out;
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Biometrics behind an interface, so tests do not need a fingerprint.
abstract class BiometricAuth {
  Future<bool> available();
  Future<bool> authenticate(String reason);
}

class LocalBiometricAuth implements BiometricAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // biometricOnly: the device screen lock must not stand in for the clinician PIN.
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } on LocalAuthException {
      return false;
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>((ref) => LocalBiometricAuth());

final biometricAvailableProvider = FutureProvider<bool>((ref) => ref.watch(biometricAuthProvider).available());

/// Iterations for new PINs. Tests override it to stay fast.
final pinIterationsProvider = Provider<int>((ref) => 120000);

class ClinicalLockState {
  const ClinicalLockState({
    this.configured = false,
    this.unlocked = false,
    this.biometricEnabled = false,
    this.failures = 0,
    this.lockedUntil,
  });

  /// A PIN exists. Until then the clinical area asks for one to be created.
  final bool configured;
  final bool unlocked;
  final bool biometricEnabled;
  final int failures;
  final DateTime? lockedUntil;

  ClinicalLockState copyWith({
    bool? configured,
    bool? unlocked,
    bool? biometricEnabled,
    int? failures,
    DateTime? Function()? lockedUntil,
  }) =>
      ClinicalLockState(
        configured: configured ?? this.configured,
        unlocked: unlocked ?? this.unlocked,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        failures: failures ?? this.failures,
        lockedUntil: lockedUntil != null ? lockedUntil() : this.lockedUntil,
      );
}

sealed class UnlockResult {
  const UnlockResult();
}

class Unlocked extends UnlockResult {
  const Unlocked();
}

class WrongPin extends UnlockResult {
  const WrongPin(this.attemptsLeft);
  final int attemptsLeft;
}

class LockedOut extends UnlockResult {
  const LockedOut(this.until);
  final DateTime until;
}

final clinicalLockProvider = AsyncNotifierProvider<ClinicalLockController, ClinicalLockState>(
  ClinicalLockController.new,
);

/// Guards the clinical area (recordings, review, reports).
///
/// The PIN is stored as a salted PBKDF2 hash inside the encrypted store, and
/// the failure count is persisted so restarting the app does not reset it.
/// After every [attemptsPerRound] wrong PINs, entry is blocked for 30 s,
/// doubling each round up to 15 min.
class ClinicalLockController extends AsyncNotifier<ClinicalLockState> {
  static const file = 'clinician.json';
  static const pinLength = 6;
  static const attemptsPerRound = 5;

  Map<String, Object?>? _record;

  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<ClinicalLockState> build() async {
    final bytes = await ref.watch(blobStoreProvider).read(file);
    if (bytes == null) return const ClinicalLockState();
    _record = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    final until = _record!['lockedUntil'] as int?;
    return ClinicalLockState(
      configured: true,
      biometricEnabled: _record!['biometric'] as bool? ?? false,
      failures: _record!['failures'] as int? ?? 0,
      lockedUntil: until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
    );
  }

  ClinicalLockState get _state => state.requireValue;

  static bool isValidPin(String pin) => pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);

  /// Creates or replaces the PIN. Callers changing an existing PIN must have
  /// checked the old one with [verify] first.
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('The PIN must be $pinLength digits');
    final salt = Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256)));
    final iterations = ref.read(pinIterationsProvider);
    final hash = await _derive(pin, salt, iterations);
    _record = {
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
      'iterations': iterations,
      'failures': 0,
      'lockedUntil': null,
      'biometric': _record?['biometric'] ?? false,
    };
    await _persist();
    state = AsyncData(_state.copyWith(configured: true, unlocked: true, failures: 0, lockedUntil: () => null));
  }

  /// Checks a PIN, counting failures. Unlocks on success.
  Future<UnlockResult> unlock(String pin) async {
    final result = await verify(pin);
    if (result is Unlocked) state = AsyncData(_state.copyWith(unlocked: true));
    return result;
  }

  /// Checks a PIN without changing the lock (used before changing the PIN).
  Future<UnlockResult> verify(String pin) async {
    final record = _record;
    if (record == null) throw StateError('No PIN set');
    final until = _state.lockedUntil;
    if (until != null && _now().isBefore(until)) return LockedOut(until);

    final salt = base64Decode(record['salt']! as String);
    final expected = base64Decode(record['hash']! as String);
    final actual = await _derive(pin, salt, record['iterations']! as int);

    if (_constantTimeEquals(actual, expected)) {
      record['failures'] = 0;
      record['lockedUntil'] = null;
      await _persist();
      state = AsyncData(_state.copyWith(failures: 0, lockedUntil: () => null));
      return const Unlocked();
    }

    final failures = _state.failures + 1;
    DateTime? lockedUntil;
    if (failures % attemptsPerRound == 0) {
      final round = failures ~/ attemptsPerRound;
      final seconds = min(30 * pow(2, round - 1).toInt(), 15 * 60);
      lockedUntil = _now().add(Duration(seconds: seconds));
    }
    record['failures'] = failures;
    record['lockedUntil'] = lockedUntil?.millisecondsSinceEpoch;
    await _persist();
    state = AsyncData(_state.copyWith(failures: failures, lockedUntil: () => lockedUntil));
    return lockedUntil != null ? LockedOut(lockedUntil) : WrongPin(attemptsPerRound - failures % attemptsPerRound);
  }

  Future<bool> unlockWithBiometrics({String reason = 'Unlock the clinical area'}) async {
    if (!_state.biometricEnabled) return false;
    final until = _state.lockedUntil;
    if (until != null && _now().isBefore(until)) return false;
    final ok = await ref.read(biometricAuthProvider).authenticate(reason);
    if (ok) state = AsyncData(_state.copyWith(unlocked: true));
    return ok;
  }

  /// Turning biometrics on needs a successful scan, so it cannot be enabled
  /// for someone else's finger by accident.
  Future<bool> setBiometricEnabled(bool enabled, {String reason = 'Confirm to enable fingerprint unlock'}) async {
    if (enabled) {
      final auth = ref.read(biometricAuthProvider);
      if (!await auth.available() || !await auth.authenticate(reason)) return false;
    }
    _record!['biometric'] = enabled;
    await _persist();
    state = AsyncData(_state.copyWith(biometricEnabled: enabled));
    return true;
  }

  void lock() {
    final current = state.value;
    if (current != null && current.unlocked) state = AsyncData(current.copyWith(unlocked: false));
  }

  Future<void> _persist() =>
      ref.read(blobStoreProvider).write(file, Uint8List.fromList(utf8.encode(jsonEncode(_record))));

  /// Off the UI thread: 120 000 iterations take a noticeable moment.
  static Future<Uint8List> _derive(String pin, List<int> salt, int iterations) =>
      Isolate.run(() => pbkdf2Sha256(utf8.encode(pin), salt, iterations));
}
