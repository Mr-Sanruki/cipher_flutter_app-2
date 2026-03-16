import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/workspace_provider.dart';
import '../../data/models/workspace_model.dart';

class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(userWorkspacesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your Workspaces')),
      body: workspacesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workspaces) => workspaces.isEmpty
            ? _buildEmpty(context)
            : _buildList(context, ref, workspaces),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => context.push('/workspace/create'),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'join',
            onPressed: () => context.push('/workspace/join'),
            icon: const Icon(Icons.group_add),
            label: const Text('Join'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF6C63FF),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspaces_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No workspaces yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Create or join a workspace to get started',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );

  Widget _buildList(BuildContext context, WidgetRef ref, List<WorkspaceModel> workspaces) =>
      ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: workspaces.length,
        itemBuilder: (context, i) {
          final ws = workspaces[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF6C63FF),
                radius: 24,
                child: Text(ws.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              title: Text(ws.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: Text('${ws.memberIds.length} members • Code: ${ws.inviteCode}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ref.read(selectedWorkspaceProvider.notifier).state = ws;
                context.go('/home');
              },
            ),
          );
        },
      );
}
