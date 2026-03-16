import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../data/models/message_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class GroupScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  @override
  void initState() {
    super.initState();

    final target = (chatType: 'group', chatId: widget.groupId);
    ref.listen<AsyncValue<List<MessageModel>>>(messagesProvider(target), (prev, next) {
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
  Widget build(BuildContext context) {
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
              backgroundColor: Colors.green.shade100,
              radius: 16,
              child: Text(
                group?.name[0].toUpperCase() ?? 'G',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 14),
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
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/chat-search/group/${widget.groupId}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () => context.push('/call/${widget.groupId}'),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGroupInfo(context, group?.memberIds ?? []),
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
                  ? const Center(child: Text('Start the conversation!'))
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
            ...memberIds.map((id) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.person_outline, color: Colors.green.shade700),
                  ),
                  title: Text(id),
                )),
          ],
        ),
      ),
    );
  }
}
