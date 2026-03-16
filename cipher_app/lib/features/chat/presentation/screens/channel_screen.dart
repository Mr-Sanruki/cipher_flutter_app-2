import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/message_model.dart';

class ChannelScreen extends ConsumerWidget {
  final String channelId;
  const ChannelScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(channelId));
    final workspace = ref.watch(selectedWorkspaceProvider);
    final user = ref.watch(authStateProvider).value;
    final isAdmin = workspace?.isAdmin(user?.uid ?? '') ?? false;
    final channelsAsync = ref.watch(channelsProvider);
    final channel = channelsAsync.value?.firstWhere(
      (c) => c.id == channelId,
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
                        chatId: channelId,
                      ),
                    ),
            ),
          ),
          MessageInputBar(
            readOnly: !isAdmin,
            readOnlyMessage: 'Only admins can post in this channel',
            onSendText: (text) => ref.read(messageNotifierProvider.notifier).sendMessage(
              chatId: channelId,
              content: text,
              type: MessageType.text,
            ),
            onSendFile: (file) => ref.read(messageNotifierProvider.notifier).sendFile(channelId, file),
          ),
        ],
      ),
    );
  }
}
