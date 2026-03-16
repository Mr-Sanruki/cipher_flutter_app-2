import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final streamVideoProvider = Provider<StreamVideo>((ref) {
  final userId = ref.watch(backendUserIdProvider);
  final streamVideo = StreamVideo(
    AppConstants.streamApiKey,
    user: User(info: UserInfo(id: userId ?? 'anonymous')),
  );
  return streamVideo;
});
