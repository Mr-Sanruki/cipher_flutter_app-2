import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/data/repositories/auth_repository.dart';

final presenceLifecycleProvider = Provider<void>((ref) {
  final isAuthed = ref.watch(authTokenProvider) != null;
  if (!isAuthed) return;

  final handler = _PresenceLifecycleHandler(
    setOnline: () => ref.read(authRepositoryProvider).setPresence(isOnline: true),
    setOffline: () => ref.read(authRepositoryProvider).setPresence(isOnline: false),
  );

  WidgetsBinding.instance.addObserver(handler);
  handler.onStart();

  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(handler);
  });
});

class _PresenceLifecycleHandler extends WidgetsBindingObserver {
  final Future<void> Function() setOnline;
  final Future<void> Function() setOffline;

  _PresenceLifecycleHandler({
    required this.setOnline,
    required this.setOffline,
  });

  void onStart() {
    setOnline();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        setOffline();
        break;
    }
  }
}
