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
  bool _micOn = true;
  bool _camOn = true;
  bool _speakerOn = true;

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
      callContentBuilder: (context, call, callState) {
        return Stack(
          children: [
            StreamCallContent(
              call: call,
              callState: callState,
              pictureInPictureConfiguration: const PictureInPictureConfiguration(
                enablePictureInPicture: false,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: SafeArea(
                top: false,
                child: _BottomControls(
                  micOn: _micOn,
                  camOn: _camOn,
                  speakerOn: _speakerOn,
                  onToggleMic: () async {
                    final next = !_micOn;
                    try {
                      final c = call as dynamic;
                      await c.setMicrophoneEnabled(enabled: next);
                      if (mounted) setState(() => _micOn = next);
                    } catch (_) {}
                  },
                  onToggleCam: () async {
                    final next = !_camOn;
                    try {
                      final c = call as dynamic;
                      await c.setCameraEnabled(enabled: next);
                      if (mounted) setState(() => _camOn = next);
                    } catch (_) {}
                  },
                  onFlipCam: () async {
                    try {
                      await call.flipCamera();
                    } catch (_) {}
                  },
                  onToggleSpeaker: () async {
                    final next = !_speakerOn;
                    try {
                      final c = call as dynamic;
                      try {
                        await c.setSpeakerphoneEnabled(enabled: next);
                      } catch (_) {
                        await c.setSpeakerEnabled(enabled: next);
                      }
                      if (mounted) setState(() => _speakerOn = next);
                    } catch (_) {}
                  },
                  onEnd: () async {
                    try {
                      await call.leave();
                    } catch (_) {}
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ),
            ),
          ],
        );
      },
      pictureInPictureConfiguration: const PictureInPictureConfiguration(
        enablePictureInPicture: false,
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final bool micOn;
  final bool camOn;
  final bool speakerOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCam;
  final VoidCallback onFlipCam;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEnd;

  const _BottomControls({
    required this.micOn,
    required this.camOn,
    required this.speakerOn,
    required this.onToggleMic,
    required this.onToggleCam,
    required this.onFlipCam,
    required this.onToggleSpeaker,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceContainerHighest.withValues(alpha: 0.88);
    final fg = cs.onSurface;

    Widget btn({required IconData icon, required VoidCallback onTap, bool danger = false}) {
      return InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: danger ? cs.error : bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: danger ? cs.onError : fg),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn(icon: micOn ? Icons.mic : Icons.mic_off, onTap: onToggleMic),
        btn(icon: camOn ? Icons.videocam : Icons.videocam_off, onTap: onToggleCam),
        btn(icon: Icons.cameraswitch, onTap: onFlipCam),
        btn(icon: speakerOn ? Icons.volume_up : Icons.volume_off, onTap: onToggleSpeaker),
        btn(icon: Icons.call_end, onTap: onEnd, danger: true),
      ],
    );
  }
}
