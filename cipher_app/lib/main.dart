import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/presence/presence_lifecycle.dart';
import 'core/notifications/notification_service.dart';
import 'features/calls/presentation/providers/incoming_call_provider.dart';
import 'features/chat/data/repositories/chat_repository.dart';
import 'features/auth/presentation/providers/user_lookup_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.settingsBox);
  runApp(const ProviderScope(child: CipherApp()));
}

class CipherApp extends ConsumerStatefulWidget {
  const CipherApp({super.key});

  @override
  ConsumerState<CipherApp> createState() => _CipherAppState();
}

class _CipherAppState extends ConsumerState<CipherApp> {
  ProviderSubscription<IncomingCallState>? _incomingCallSub;
  bool _incomingSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _incomingCallSub = ref.listenManual(incomingCallProvider, (prev, next) {
      if (next.hasCall && (prev?.callId != next.callId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showIncomingCall(next.fromUserId!, next.callId!, next.callType);
        });
      }
    });
  }

  @override
  void dispose() {
    _incomingCallSub?.close();
    super.dispose();
  }

  Future<void> _showIncomingCall(String fromUserId, String callId, String callType) async {
    if (_incomingSheetOpen) return;
    final navCtx = rootNavigatorKey.currentContext;
    if (navCtx == null) return;
    _incomingSheetOpen = true;

    final uAsync = ref.read(userByIdProvider(fromUserId));
    final u = uAsync.value;

    const normalizedType = 'video';

    await showModalBottomSheet<void>(
      context: navCtx,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: u?.avatarUrl != null && (u!.avatarUrl ?? '').isNotEmpty ? NetworkImage(u.avatarUrl!) : null,
                    child: (u?.avatarUrl == null || (u!.avatarUrl ?? '').isEmpty) ? const Icon(Icons.person_outline) : null,
                  ),
                  title: Text(u?.name ?? fromUserId, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Incoming video call'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(incomingCallProvider.notifier).clear();
                          ref.read(chatRepositoryProvider).sendCallDecline(toUserId: fromUserId, callId: callId, callType: normalizedType);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.call_end, color: Colors.red),
                        label: const Text('Decline', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(incomingCallProvider.notifier).clear();
                          ref.read(chatRepositoryProvider).sendCallAccept(toUserId: fromUserId, callId: callId, callType: normalizedType);
                          Navigator.pop(ctx);
                          navCtx.push('/video-call/$callId');
                        },
                        icon: const Icon(Icons.videocam),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    _incomingSheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(presenceLifecycleProvider);
    ref.watch(notificationLifecycleProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
