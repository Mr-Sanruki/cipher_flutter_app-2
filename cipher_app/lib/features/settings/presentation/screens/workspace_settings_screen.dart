import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../workspace/data/repositories/workspace_repository.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class WorkspaceSettingsScreen extends ConsumerStatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  ConsumerState<WorkspaceSettingsScreen> createState() => _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends ConsumerState<WorkspaceSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final ws = ref.read(selectedWorkspaceProvider);
    _nameCtrl = TextEditingController(text: ws?.name ?? '');
    _descCtrl = TextEditingController(text: ws?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final ws = ref.read(selectedWorkspaceProvider);
      if (ws == null) return;
      final updated = ws.copyWith(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      await ref.read(workspaceRepositoryProvider).updateWorkspace(updated);
      ref.read(selectedWorkspaceProvider.notifier).setWorkspace(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace updated!')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(selectedWorkspaceProvider);
    final backendUserId = ref.watch(backendUserIdProvider);
    final isOwner = ws?.ownerId == backendUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace Settings'),
        actions: [
          if (isOwner)
            TextButton(
              onPressed: _loading ? null : _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ws == null
          ? const Center(child: Text('No workspace selected'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Invite Code Card
                Card(
                  color: const Color(0xFF6C63FF).withAlpha(13),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invite Code',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(ws.inviteCode,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                                    letterSpacing: 4, color: Color(0xFF6C63FF))),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: ws.inviteCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invite code copied!')));
                              },
                            ),
                          ],
                        ),
                        Text('Share this code to let others join',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                Row(
                  children: [
                    Expanded(child: _statCard('Members', ws.memberIds.length.toString(), Icons.group_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Admins', ws.adminIds.length.toString(), Icons.admin_panel_settings_outlined)),
                  ],
                ),
                const SizedBox(height: 24),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('Member Directory'),
                    subtitle: const Text('View members and roles'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/settings/members'),
                  ),
                ),
                const SizedBox(height: 16),

                if (isOwner) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Workspace name', prefixIcon: Icon(Icons.workspaces_outlined)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                ],

                // Leave workspace
                OutlinedButton.icon(
                  onPressed: () => _confirmLeave(context),
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  label: const Text('Leave Workspace', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    ),
  );

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Workspace'),
        content: const Text('Are you sure you want to leave this workspace?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final ws = ref.read(selectedWorkspaceProvider);
              if (ws == null) return;
              await ref.read(workspaceNotifierProvider.notifier).leaveWorkspace(ws.id);
              if (context.mounted) context.go('/workspace');
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
