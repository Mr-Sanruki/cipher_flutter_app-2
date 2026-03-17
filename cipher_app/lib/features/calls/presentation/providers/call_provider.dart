import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/repositories/auth_repository.dart';

final streamVideoProvider = FutureProvider<StreamVideo>((ref) async {
  final userId = ref.watch(backendUserIdProvider);
  if (userId == null) {
    return StreamVideo(
      AppConstants.streamApiKey,
      user: const User(info: UserInfo(id: 'anonymous')),
    );
  }

  final token = await ref.watch(authRepositoryProvider).getStreamUserToken();
  return StreamVideo(
    AppConstants.streamApiKey,
    user: User(info: UserInfo(id: userId)),
    userToken: token,
  );
});
