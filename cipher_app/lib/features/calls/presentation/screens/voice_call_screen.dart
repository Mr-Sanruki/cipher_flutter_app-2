import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../providers/call_provider.dart';
import '../../../auth/presentation/providers/user_lookup_provider.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  final String callId;
  const VoiceCallScreen({super.key, required this.callId});

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> {
  Call? _call;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnecting = true;
  String _status = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      final streamVideo = await ref.read(streamVideoProvider.future);
      _call = streamVideo.makeCall(callType: StreamCallType.defaultType(), id: widget.callId);
      await _call!.getOrCreate();
      await _call!.join();
      setState(() {
        _isConnecting = false;
        _status = 'Connected';
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _status = 'Failed to connect: $e';
      });
    }
  }

  Future<void> _endCall() async {
    await _call?.leave();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleMute() async {
    if (_isMuted) {
      await _call?.setMicrophoneEnabled(enabled: true);
    } else {
      await _call?.setMicrophoneEnabled(enabled: false);
    }
    setState(() => _isMuted = !_isMuted);
  }

  @override
  void dispose() {
    _call?.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userByIdProvider(widget.callId));
    final user = userAsync.value;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF6C63FF),
                    backgroundImage: user?.avatarUrl != null && (user!.avatarUrl ?? '').isNotEmpty
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: (user?.avatarUrl == null || (user!.avatarUrl ?? '').isEmpty)
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? widget.callId,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isConnecting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                        ),
                      if (_isConnecting) const SizedBox(width: 8),
                      Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onTap: _toggleMute,
                    color: _isMuted ? Colors.red : Colors.white24,
                  ),
                  // End call button
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                    ),
                  ),
                  _controlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    label: 'Speaker',
                    onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                    color: _isSpeakerOn ? const Color(0xFF6C63FF) : Colors.white24,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    ),
  );
}
