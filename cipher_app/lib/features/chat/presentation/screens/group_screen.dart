import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/user_lookup_provider.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';

class GroupScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  ProviderSubscription<AsyncValue<List<MessageModel>>>? _messagesSub;

  Future<void> _showSummary(BuildContext context) async {
    try {
      final data = await ref.read(chatRepositoryProvider).summarizeChat(
            chatType: 'group',
            chatId: widget.groupId,
          );
      final summary = (data['summary'] ?? '').toString().trim();
      final items = (data['actionItems'] is List) ? (data['actionItems'] as List) : const [];

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI Summary'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(summary.isNotEmpty ? summary : 'No summary'),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Action items', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('- ${(it is Map ? it['task'] : it).toString()}'),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void initState() {
    super.initState();

    final target = (chatType: 'group', chatId: widget.groupId);
    _messagesSub = ref.listenManual<AsyncValue<List<MessageModel>>>(messagesProvider(target), (prev, next) {
      final myId = ref.read(backendUserIdProvider);
      if (myId == null) return;

      next.whenData((messages) {
        final toDeliver = <String>[];
        final toRead = <String>[];

        for (final m in messages) {
          if (m.senderId == myId) continue;
          if (!m.deliveredTo.containsKey(myId)) toDeliver.add(m.id);
          if (!m.readBy.containsKey(myId)) toRead.add(m.id);
        }

        if (toDeliver.isNotEmpty) {
          ref.read(messageNotifierProvider.notifier).markDelivered(chatType: 'group', chatId: widget.groupId, messageIds: toDeliver);
        }
        if (toRead.isNotEmpty) {
          ref.read(messageNotifierProvider.notifier).markRead(chatType: 'group', chatId: widget.groupId, messageIds: toRead);
        }
      });
    });
  }

  @override
  void dispose() {
    _messagesSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final messagesAsync = ref.watch(messagesProvider((chatType: 'group', chatId: widget.groupId)));
    final groupsAsync = ref.watch(groupsProvider);
    final group = groupsAsync.value?.firstWhere(
      (g) => g.id == widget.groupId,
      orElse: () => groupsAsync.value!.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: cs.surfaceContainerHighest,
              radius: 16,
              child: Text(
                group?.name[0].toUpperCase() ?? 'G',
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group?.name ?? 'Group',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (group != null)
                  Text('${group.memberIds.length} members',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.65))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {
              context.push('/chat-search/group/${widget.groupId}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => _showSummary(context),
            tooltip: 'AI summary',
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => _showAddMembers(context, group?.memberIds ?? const []),
            tooltip: 'Add members',
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group calls are not supported yet. Start a DM call instead.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGroupInfo(context, group?.memberIds ?? []),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') {
                await ref.read(messageNotifierProvider.notifier).clearChat(chatType: 'group', chatId: widget.groupId);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) => messages.isEmpty
                  ? Center(
                      child: Text(
                        'Start the conversation!',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (_, i) => MessageBubble(message: messages[i], chatType: 'group', chatId: widget.groupId),
                    ),
            ),
          ),
          MessageInputBar(
            onSendText: (text) => ref.read(messageNotifierProvider.notifier).sendMessage(
              chatType: 'group',
              chatId: widget.groupId,
              content: text,
              type: MessageType.text,
            ),
            onSendFile: (file) => ref.read(messageNotifierProvider.notifier).sendFile(chatType: 'group', chatId: widget.groupId, file: file),
          ),
        ],
      ),
    );
  }

  void _showGroupInfo(BuildContext context, List<String> memberIds) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: memberIds.map((id) {
                  final uAsync = ref.watch(userByIdProvider(id));
                  final u = uAsync.value;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      backgroundImage: u?.avatarUrl != null && (u!.avatarUrl ?? '').isNotEmpty
                          ? NetworkImage(u.avatarUrl!)
                          : null,
                      child: (u?.avatarUrl == null || (u!.avatarUrl ?? '').isEmpty)
                          ? Icon(Icons.person_outline, color: Colors.green.shade700)
                          : null,
                    ),
                    title: Text(u?.name ?? id),
                    subtitle: u?.email != null ? Text(u!.email, overflow: TextOverflow.ellipsis) : null,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMembers(BuildContext context, List<String> existingMemberIds) async {
    final ws = ref.read(selectedWorkspaceProvider);
    final myId = ref.read(backendUserIdProvider);
    if (ws == null || myId == null) return;

    final members = await ref.read(authRepositoryProvider).getUsersByIds(ws.memberIds);
    final existing = existingMemberIds.toSet();
    final candidates = members.where((u) => !existing.contains(u.id)).toList();

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
              child: Text('Add members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text('Everyone is already in this group.'),
              ),
            for (final u in candidates)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(u.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(u.email, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(chatRepositoryProvider).addMembersToGroup(
                          groupId: widget.groupId,
                          memberIds: [u.id],
                        );
                    ref.invalidate(groupsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added ${u.name}')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
