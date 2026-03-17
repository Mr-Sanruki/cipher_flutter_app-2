import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/message_model.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  final String channelId;
  const ChannelScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  @override
  void initState() {
    super.initState();

    final target = (chatType: 'channel', chatId: widget.channelId);
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
          ref.read(messageNotifierProvider.notifier).markDelivered(chatType: 'channel', chatId: widget.channelId, messageIds: toDeliver);
        }
        if (toRead.isNotEmpty) {
          ref.read(messageNotifierProvider.notifier).markRead(chatType: 'channel', chatId: widget.channelId, messageIds: toRead);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider((chatType: 'channel', chatId: widget.channelId)));
    final workspace = ref.watch(selectedWorkspaceProvider);
    final myId = ref.watch(backendUserIdProvider);
    final isAdmin = workspace?.isAdmin(myId ?? '') ?? false;
    final channelsAsync = ref.watch(channelsProvider);
    final channel = channelsAsync.value?.firstWhere(
      (c) => c.id == widget.channelId,
      orElse: () => channelsAsync.value!.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('# ${channel?.name ?? 'Channel'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (channel?.isAnnouncement == true)
              const Text('Announcement channel',
                  style: TextStyle(fontSize: 11, color: Colors.orange)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {
              context.push('/chat-search/channel/${widget.channelId}');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') {
                await ref.read(messageNotifierProvider.notifier).clearChat(chatType: 'channel', chatId: widget.channelId);
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
                  ? const Center(child: Text('No messages yet. Be the first to post!'))
                  : ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (_, i) => MessageBubble(
                        message: messages[i],
                        chatType: 'channel',
                        chatId: widget.channelId,
                      ),
                    ),
            ),
          ),
          MessageInputBar(
            readOnly: !isAdmin,
            readOnlyMessage: 'Only admins can post in this channel',
            onSendText: (text) => ref.read(messageNotifierProvider.notifier).sendMessage(
              chatType: 'channel',
              chatId: widget.channelId,
              content: text,
              type: MessageType.text,
            ),
            onSendFile: (file) => ref.read(messageNotifierProvider.notifier).sendFile(chatType: 'channel', chatId: widget.channelId, file: file),
          ),
        ],
      ),
    );
  }
}
