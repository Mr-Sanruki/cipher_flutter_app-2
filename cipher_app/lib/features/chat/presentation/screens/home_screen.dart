import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/user_lookup_provider.dart';
import '../../../calls/presentation/providers/incoming_call_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  void _showWorkspaceSwitcher() {
    final workspacesAsync = ref.read(userWorkspacesProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Switch workspace',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                workspacesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text('Error: $e')),
                  ),
                  data: (workspaces) {
                    final selected = ref.read(selectedWorkspaceProvider);
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: workspaces.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final ws = workspaces[i];
                        final isSelected = selected?.id == ws.id;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF6C63FF),
                            child: Text(
                              ws.name.isNotEmpty ? ws.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(ws.name, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${ws.memberIds.length} members'),
                          trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF6C63FF)) : null,
                          onTap: () {
                            ref.read(selectedWorkspaceProvider.notifier).setWorkspace(ws);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/workspace');
                        },
                        icon: const Icon(Icons.workspaces_outlined),
                        label: const Text('Manage workspaces'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(incomingCallProvider, (prev, next) {
      if (next.hasCall && (prev?.callId != next.callId)) {
        _showIncomingCall(context, next.fromUserId!, next.callId!);
      }
    });

    final workspace = ref.watch(selectedWorkspaceProvider);
    if (workspace == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/workspace'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showWorkspaceSwitcher,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
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
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
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

  Future<void> _showIncomingCall(BuildContext context, String fromUserId, String callId) async {
    final uAsync = ref.read(userByIdProvider(fromUserId));
    final u = uAsync.value;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: u?.avatarUrl != null && (u!.avatarUrl ?? '').isNotEmpty ? NetworkImage(u.avatarUrl!) : null,
                    child: (u?.avatarUrl == null || (u!.avatarUrl ?? '').isEmpty) ? const Icon(Icons.person_outline) : null,
                  ),
                  title: Text(u?.name ?? fromUserId, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Incoming call'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(incomingCallProvider.notifier).clear();
                          ref.read(chatRepositoryProvider).sendCallDecline(toUserId: fromUserId, callId: callId);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.call_end, color: Colors.red),
                        label: const Text('Decline', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(incomingCallProvider.notifier).clear();
                          ref.read(chatRepositoryProvider).sendCallAccept(toUserId: fromUserId, callId: callId);
                          Navigator.pop(ctx);
                          context.push('/call/$callId');
                        },
                        icon: const Icon(Icons.call),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
    final myId = ref.watch(backendUserIdProvider);
    final isAdmin = workspace?.isAdmin(myId ?? '') ?? false;

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
              heroTag: 'home_channels_fab',
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

  Future<void> _showNewDmPicker(BuildContext context, WidgetRef ref) async {
    final ws = ref.read(selectedWorkspaceProvider);
    final myId = ref.read(backendUserIdProvider);
    if (ws == null || myId == null) return;

    final members = await ref.read(authRepositoryProvider).getUsersByIds(ws.memberIds);
    final candidates = members.where((u) => u.id != myId).toList();

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('Start a DM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text('No other members in this workspace.'),
              ),
            for (final u in candidates)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(u.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(u.email, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  Navigator.pop(ctx);
                  final dm = await ref.read(chatRepositoryProvider).getOrCreateDm(
                        workspaceId: ws.id,
                        otherUserId: u.id,
                      );
                  if (context.mounted) context.push('/dm/${dm.id}');
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmsAsync = ref.watch(dmsProvider);
    return Scaffold(
      body: dmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (dms) => dms.isEmpty
            ? _emptyState(context, 'No direct messages', Icons.chat_bubble_outline)
            : ListView.builder(
                itemCount: dms.length,
                itemBuilder: (context, i) {
                  final dm = dms[i];
                  final myId = ref.read(backendUserIdProvider);
                  final otherId = myId != null ? dm.otherUserId(myId) : 'User';
                  final otherUserAsync = myId != null ? ref.watch(userByIdProvider(otherId)) : const AsyncValue.data(null);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.person_outline, color: Colors.blue.shade700),
                    ),
                    title: Text(
                      otherUserAsync.value?.name ?? otherId,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: dm.lastMessage != null
                        ? Text(dm.lastMessage!, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12))
                        : null,
                    onTap: () => context.push('/dm/${dm.id}'),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_dms_fab',
        onPressed: () => _showNewDmPicker(context, ref),
        child: const Icon(Icons.chat_bubble_outline),
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
        heroTag: 'home_groups_fab',
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
                final myId = ref.read(backendUserIdProvider);
                await ref.read(chatSetupNotifierProvider.notifier)
                    .createGroup(nameCtrl.text.trim(), [myId ?? '']);
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
