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
      callContentBuilder: (context, call, callState) {
        final local = callState.localParticipant;
        if (local == null) {
          return StreamCallContent(
            call: call,
            callState: callState,
            pictureInPictureConfiguration: const PictureInPictureConfiguration(
              enablePictureInPicture: false,
            ),
          );
        }

        return StreamCallContent(
          call: call,
          callState: callState,
          pictureInPictureConfiguration: const PictureInPictureConfiguration(
            enablePictureInPicture: false,
            disablePictureInPictureWhenScreenSharing: true,
          ),
          callControlsBuilder: (context, call, callState) {
            final localParticipant = callState.localParticipant;
            if (localParticipant == null) return const SizedBox.shrink();

            final base = defaultCallControlOptions(
              call: call,
              localParticipant: localParticipant,
            );

            return StreamCallControls(
              options: [
                ...base,
                ToggleScreenShareOption(call: call, localParticipant: localParticipant),
              ],
            );
          },
        );
      },
      pictureInPictureConfiguration: const PictureInPictureConfiguration(
        enablePictureInPicture: false,
      ),
    );
  }
}
