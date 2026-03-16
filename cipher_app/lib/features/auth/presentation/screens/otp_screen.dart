import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_submitting) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _submitting = true);
    await ref.read(authNotifierProvider.notifier).verifyOtp(email: widget.email, code: code);
    if (!mounted) return;
    final state = ref.read(authNotifierProvider);
    if (state is! AsyncError) {
      context.go('/workspace');
    } else {
      final err = state.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $err')),
      );
      setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    await ref.read(authNotifierProvider.notifier).sendOtp(widget.email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login code resent!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.mark_email_unread_outlined, size: 56, color: Color(0xFF6C63FF)),
            const SizedBox(height: 24),
            Text('Check your email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            Text('We sent a 6-digit login code to ${widget.email}. Enter it below.',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '6-digit code',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (authState.isLoading || _submitting) ? null : _verify,
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Verify & Login'),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _resend,
                child: const Text('Resend link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
