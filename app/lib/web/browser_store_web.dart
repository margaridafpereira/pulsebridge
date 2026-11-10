import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../sessions/session_repository.dart';

BlobStore browserStore() => _LocalStorageBlobStore();

/// The web demo keeps its data in this browser's localStorage. Unlike the
/// Android app it is not encrypted with a hardware key: the demo only ever
/// holds simulated recordings, and the app says so.
class _LocalStorageBlobStore implements BlobStore {
  static const _prefix = 'pulsebridge:';
  web.Storage get _storage => web.window.localStorage;

  @override
  Future<void> write(String name, Uint8List data) async => _storage.setItem('$_prefix$name', base64Encode(data));

  @override
  Future<Uint8List?> read(String name) async {
    final v = _storage.getItem('$_prefix$name');
    return v == null ? null : base64Decode(v);
  }

  @override
  Future<List<String>> list(String prefix) async => [
        for (var i = 0; i < _storage.length; i++)
          if (_storage.key(i) case final String k when k.startsWith('$_prefix$prefix')) k.substring(_prefix.length),
      ]..sort();

  @override
  Future<bool> delete(String name) async {
    final had = _storage.getItem('$_prefix$name') != null;
    _storage.removeItem('$_prefix$name');
    return had;
  }
}
