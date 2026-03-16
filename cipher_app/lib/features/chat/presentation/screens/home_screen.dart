import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(selectedWorkspaceProvider);
    if (workspace == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/workspace'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF6C63FF),
              radius: 16,
              child: Text(workspace.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(workspace.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => context.push('/ai'),
            tooltip: 'AI Assistant',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _ChannelsTab(),
          _DmsTab(),
          _GroupsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tag), label: 'Channels'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'DMs'),
          NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Groups'),
        ],
      ),
    );
  }
}

// ─── Channels Tab ───────────────────────────────────────────────
class _ChannelsTab extends ConsumerWidget {
  const _ChannelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider);
    final workspace = ref.watch(selectedWorkspaceProvider);
    final user = ref.watch(authStateProvider).value;
    final isAdmin = workspace?.isAdmin(user?.uid ?? '') ?? false;

    return Scaffold(
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (channels) => channels.isEmpty
            ? _emptyState(context, 'No channels yet', Icons.tag)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: channels.length,
                itemBuilder: (context, i) {
                  final ch = channels[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ch.isAnnouncement
                          ? Colors.orange.shade100
                          : Colors.purple.shade100,
                      child: Icon(
                        ch.isAnnouncement ? Icons.campaign_outlined : Icons.tag,
                        color: ch.isAnnouncement ? Colors.orange : Colors.purple,
                        size: 20,
                      ),
                    ),
                    title: Text(ch.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(ch.isAnnouncement ? 'Announcement' : 'Channel',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    onTap: () => context.push('/channel/${ch.id}'),
                  );
                },
              ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCreateChannel(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showCreateChannel(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    bool isAnnouncement = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Channel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Channel name', prefixIcon: Icon(Icons.tag)),
              ),
              SwitchListTile(
                value: isAnnouncement,
                onChanged: (v) => setState(() => isAnnouncement = v),
                title: const Text('Announcement channel'),
                subtitle: const Text('Only admins can post'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  await ref.read(chatSetupNotifierProvider.notifier)
                      .createChannel(nameCtrl.text.trim(), isAnnouncement: isAnnouncement);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DMs Tab ────────────────────────────────────────────────────
class _DmsTab extends ConsumerWidget {
  const _DmsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmsAsync = ref.watch(dmsProvider);
    return dmsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (dms) => dms.isEmpty
          ? _emptyState(context, 'No direct messages', Icons.chat_bubble_outline)
          : ListView.builder(
              itemCount: dms.length,
              itemBuilder: (context, i) {
                final dm = dms[i];
                final user = ref.read(authStateProvider).value;
                final otherId = dm.otherUserId(user?.uid ?? '');
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.person_outline, color: Colors.blue.shade700),
                  ),
                  title: Text(otherId, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: dm.lastMessage != null
                      ? Text(dm.lastMessage!, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12))
                      : null,
                  onTap: () => context.push('/dm/${dm.id}'),
                );
              },
            ),
    );
  }
}

// ─── Groups Tab ─────────────────────────────────────────────────
class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    return Scaffold(
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (groups) => groups.isEmpty
            ? _emptyState(context, 'No groups yet', Icons.group_outlined)
            : ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final g = groups[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Text(g.name[0].toUpperCase(),
                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${g.memberIds.length} members',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    onTap: () => context.push('/group/${g.id}'),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroup(context, ref),
        child: const Icon(Icons.group_add),
      ),
    );
  }

  void _showCreateGroup(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Group name', prefixIcon: Icon(Icons.group_outlined)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                final user = ref.read(authStateProvider).value;
                await ref.read(chatSetupNotifierProvider.notifier)
                    .createGroup(nameCtrl.text.trim(), [user?.uid ?? '']);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _emptyState(BuildContext context, String message, IconData icon) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
    ],
  ),
);
