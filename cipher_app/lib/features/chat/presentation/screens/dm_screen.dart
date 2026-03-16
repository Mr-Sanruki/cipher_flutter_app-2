import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/message_model.dart';

class DmScreen extends ConsumerStatefulWidget {
  final String dmId;
  const DmScreen({super.key, required this.dmId});

  @override
  ConsumerState<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends ConsumerState<DmScreen> {
  @override
  void initState() {
    super.initState();

    final target = (chatType: 'dm', chatId: widget.dmId);
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
          ref.read(messageNotifierProvider.notifier).markDelivered(chatType: 'dm', chatId: widget.dmId, messageIds: toDeliver);
        }
        if (toRead.isNotEmpty) {
          ref.read(messageNotifierProvider.notifier).markRead(chatType: 'dm', chatId: widget.dmId, messageIds: toRead);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider((chatType: 'dm', chatId: widget.dmId)));
    final dmsAsync = ref.watch(dmsProvider);
    final myId = ref.watch(backendUserIdProvider);
    final dm = dmsAsync.value?.firstWhere((d) => d.id == widget.dmId, orElse: () => dmsAsync.value!.first);
    final otherId = dm != null && myId != null ? dm.otherUserId(myId) : 'User';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              radius: 16,
              child: Icon(Icons.person_outline, color: Colors.blue.shade700, size: 18),
            ),
            const SizedBox(width: 8),
            Text(otherId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/chat-search/dm/${widget.dmId}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () => context.push('/call/${widget.dmId}'),
            tooltip: 'Voice call',
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
                  ? const Center(child: Text('Start a conversation!'))
                  : ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (_, i) => MessageBubble(message: messages[i], chatType: 'dm', chatId: widget.dmId),
                    ),
            ),
          ),
          MessageInputBar(
            onSendText: (text) => ref.read(messageNotifierProvider.notifier).sendMessage(
              chatType: 'dm',
              chatId: widget.dmId,
              content: text,
              type: MessageType.text,
            ),
            onSendFile: (file) => ref.read(messageNotifierProvider.notifier).sendFile(chatType: 'dm', chatId: widget.dmId, file: file),
          ),
        ],
      ),
    );
  }
}
