import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationLifecycleProvider = Provider<void>((ref) {
  final svc = ref.watch(notificationServiceProvider);
  final isAuthed = ref.watch(authTokenProvider) != null;
  if (!isAuthed) return;

  unawaited(svc.ensureRegistered());
});

class NotificationService {
  Future<void> ensureRegistered() async {
    return;
  }
}
