import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Encrypted file storage backed by the Android Keystore (AES-256-GCM).
/// The key never leaves the Keystore; see SecureStore.kt.
class SecureStore {
  const SecureStore();

  @visibleForTesting
  static const channel = MethodChannel('pt.margaridapereira.device_link/store');

  Future<void> write(String name, Uint8List data) => channel.invokeMethod('write', {'name': name, 'data': data});

  /// Returns null if [name] does not exist.
  Future<Uint8List?> read(String name) => channel.invokeMethod<Uint8List>('read', {'name': name});

  Future<List<String>> list([String prefix = '']) async =>
      (await channel.invokeListMethod<String>('list', {'prefix': prefix})) ?? const [];

  Future<bool> delete(String name) async => await channel.invokeMethod<bool>('delete', {'name': name}) ?? false;
}
