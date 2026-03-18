import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../providers/call_provider.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String callId;
  const VideoCallScreen({super.key, required this.callId});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  Call? _call;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      final streamVideo = await ref.read(streamVideoProvider.future);
      final call = streamVideo.makeCall(
        callType: StreamCallType.defaultType(),
        id: widget.callId,
      );
      await call.getOrCreate();
      try {
        final c = call as dynamic;
        await c.join(
          connectOptions: CallConnectOptions(
            speakerDefaultOn: true,
            screenShare: TrackOption.disabled(),
          ),
        );
      } catch (_) {}
      setState(() => _call = call);
    } catch (_) {
      if (mounted) setState(() => _call = null);
    }
  }

  @override
  void dispose() {
    _call?.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = _call;
    if (call == null) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return StreamCallContainer(
      call: call,
      callConnectOptions: CallConnectOptions(
        speakerDefaultOn: true,
        screenShare: TrackOption.disabled(),
      ),
      pictureInPictureConfiguration: const PictureInPictureConfiguration(
        enablePictureInPicture: false,
      ),
    );
  }
}
