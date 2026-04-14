import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../../workspace/presentation/screens/members_screen.dart';
import '../../../workspace/data/repositories/workspace_repository.dart';

class EmailMembersScreen extends ConsumerStatefulWidget {
  const EmailMembersScreen({super.key});

  @override
  ConsumerState<EmailMembersScreen> createState() => _EmailMembersScreenState();
}

class _EmailMembersScreenState extends ConsumerState<EmailMembersScreen> {
  UserModel? _selected;
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ws = ref.read(selectedWorkspaceProvider);
    final to = _selected;
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (ws == null) return;

    if (to == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a member')));
      return;
    }
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject is required')));
      return;
    }
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message is required')));
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(workspaceRepositoryProvider).sendWorkspaceEmail(
            workspaceId: ws.id,
            toUserId: to.id,
            subject: subject,
            message: message,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email sent to ${to.name}')));
      _subjectCtrl.clear();
      _messageCtrl.clear();
      setState(() => _selected = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(selectedWorkspaceProvider);
    final membersAsync = ref.watch(workspaceMembersProvider);

    if (ws == null) {
      return const Scaffold(body: Center(child: Text('No workspace selected')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email members'),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          final selectable = members.where((m) => (m.email).trim().isNotEmpty).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<UserModel>(
                        value: _selected,
                        items: selectable
                            .map(
                              (u) => DropdownMenuItem<UserModel>(
                                value: u,
                                child: Text('${u.name}  •  ${u.email}', overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: _sending ? null : (v) => setState(() => _selected = v),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Select a member',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subjectCtrl,
                        enabled: !_sending,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _messageCtrl,
                        enabled: !_sending,
                        minLines: 6,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(_sending ? 'Sending...' : 'Send email'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This sends an email to the selected member. Delivery depends on your Brevo configuration.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)),
              ),
            ],
          );
        },
      ),
    );
  }
}
