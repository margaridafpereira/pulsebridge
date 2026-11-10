import 'dart:convert';
import 'dart:typed_data';

import 'package:device_link/device_link.dart';

import 'session.dart';

/// Abstraction over the encrypted store, so tests can use memory instead.
abstract class BlobStore {
  Future<void> write(String name, Uint8List data);
  Future<Uint8List?> read(String name);
  Future<List<String>> list(String prefix);
  Future<bool> delete(String name);
}

class KeystoreBlobStore implements BlobStore {
  const KeystoreBlobStore([this._store = const SecureStore()]);
  final SecureStore _store;

  @override
  Future<void> write(String name, Uint8List data) => _store.write(name, data);
  @override
  Future<Uint8List?> read(String name) => _store.read(name);
  @override
  Future<List<String>> list(String prefix) => _store.list(prefix);
  @override
  Future<bool> delete(String name) => _store.delete(name);
}

class MemoryBlobStore implements BlobStore {
  final files = <String, Uint8List>{};

  @override
  Future<void> write(String name, Uint8List data) async => files[name] = data;
  @override
  Future<Uint8List?> read(String name) async => files[name];
  @override
  Future<List<String>> list(String prefix) async => files.keys.where((k) => k.startsWith(prefix)).toList()..sort();
  @override
  Future<bool> delete(String name) async => files.remove(name) != null;
}

/// Sessions on disk: `session_<id>.json` (metadata, heart rate, events) and
/// `session_<id>.ecg` (raw int16 samples). Both are encrypted by the store.
class SessionRepository {
  SessionRepository(this._store);
  final BlobStore _store;

  Future<void> save(Session session, Uint8List ecg) async {
    // ECG first: a session file only appears once its signal is safely written.
    await _store.write('session_${session.id}.ecg', ecg);
    await _store.write('session_${session.id}.json', utf8.encode(jsonEncode(session.toJson())));
  }

  /// Newest first.
  Future<List<Session>> list() async {
    final names = await _store.list('session_');
    final sessions = <Session>[];
    for (final name in names.where((n) => n.endsWith('.json'))) {
      final bytes = await _store.read(name);
      if (bytes != null) sessions.add(Session.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, Object?>));
    }
    return sessions..sort((a, b) => b.start.compareTo(a.start));
  }

  Future<SessionEcg?> loadEcg(Session session) async {
    final bytes = await _store.read('session_${session.id}.ecg');
    if (bytes == null) return null;
    final data = ByteData.sublistView(bytes);
    final samples = Int16List(bytes.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little);
    }
    return SessionEcg(samples, session.sampleRate);
  }

  Future<void> delete(Session session) async {
    await _store.delete('session_${session.id}.json');
    await _store.delete('session_${session.id}.ecg');
  }
}
