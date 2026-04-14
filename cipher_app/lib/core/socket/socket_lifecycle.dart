import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/chat/data/repositories/chat_repository.dart';

/// Ensures the socket connection is established as soon as the user is authenticated.
/// This allows the app to receive real-time events (messages, calls) even when
/// the user is not actively viewing a specific chat screen.
final socketLifecycleProvider = Provider<void>((ref) {
  final isAuthed = ref.watch(authTokenProvider) != null;
  if (!isAuthed) return;

  // Connect socket immediately after login.
  ref.read(chatRepositoryProvider).ensureSocketConnected();
});
