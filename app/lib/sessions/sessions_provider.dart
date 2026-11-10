import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import 'session.dart';
import 'session_repository.dart';

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(blobStoreProvider)),
);

/// Saved sessions, newest first. Invalidate after saving or deleting.
final sessionsProvider = FutureProvider<List<Session>>((ref) => ref.watch(sessionRepositoryProvider).list());
