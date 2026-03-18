import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/workspace/presentation/screens/workspace_screen.dart';
import '../../features/workspace/presentation/screens/create_workspace_screen.dart';
import '../../features/workspace/presentation/screens/join_workspace_screen.dart';
import '../../features/chat/presentation/screens/home_screen.dart';
import '../../features/chat/presentation/screens/channel_screen.dart';
import '../../features/chat/presentation/screens/dm_screen.dart';
import '../../features/chat/presentation/screens/group_screen.dart';
import '../../features/chat/presentation/screens/thread_screen.dart';
import '../../features/chat/presentation/screens/message_search_screen.dart';
import '../../features/ai/presentation/screens/ai_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/account_screen.dart';
import '../../features/settings/presentation/screens/workspace_settings_screen.dart';
import '../../features/calls/presentation/screens/voice_call_screen.dart';
import '../../features/calls/presentation/screens/video_call_screen.dart';
import '../../features/workspace/presentation/screens/members_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final token = ref.watch(authTokenProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = token != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == '/splash';
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (c, s) => OtpScreen(email: s.extra as String),
      ),
      GoRoute(path: '/workspace', builder: (c, s) => const WorkspaceScreen()),
      GoRoute(path: '/workspace/create', builder: (c, s) => const CreateWorkspaceScreen()),
      GoRoute(path: '/workspace/join', builder: (c, s) => const JoinWorkspaceScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(
        path: '/channel/:id',
        builder: (c, s) => ChannelScreen(channelId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dm/:id',
        builder: (c, s) => DmScreen(dmId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/group/:id',
        builder: (c, s) => GroupScreen(groupId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/thread/:id',
        builder: (c, s) => ThreadScreen(messageId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat-search/:type/:id',
        builder: (c, s) => MessageSearchScreen(
          chatType: s.pathParameters['type']!,
          chatId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/ai', builder: (c, s) => const AiScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/settings/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/settings/account', builder: (c, s) => const AccountScreen()),
      GoRoute(path: '/settings/workspace', builder: (c, s) => const WorkspaceSettingsScreen()),
      GoRoute(path: '/settings/members', builder: (c, s) => const MembersScreen()),
      GoRoute(
        path: '/call/:id',
        builder: (c, s) => VoiceCallScreen(callId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/video-call/:id',
        builder: (c, s) => VideoCallScreen(callId: s.pathParameters['id']!),
      ),
    ],
    errorBuilder: (c, s) => Scaffold(
      body: Center(child: Text('Page not found: ${s.error}')),
    ),
  );
});
