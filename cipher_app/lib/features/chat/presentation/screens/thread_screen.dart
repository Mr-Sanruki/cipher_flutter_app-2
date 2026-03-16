import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../data/models/message_model.dart';

class ThreadScreen extends ConsumerWidget {
  final String messageId;
  const ThreadScreen({super.key, required this.messageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = GoRouterState.of(context).extra;
    final args = extra is Map ? extra : null;
    final chatId = args?['chatId'] as String? ?? '';
    final chatType = args?['chatType'] as String? ?? '';
    final parentMessage = args?['message'] as MessageModel?;
    final threadArgs = (chatType: chatType, chatId: chatId, messageId: messageId);
    final threadsAsync = ref.watch(threadMessagesProvider(threadArgs));

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Thread'),
            SizedBox(height: 2),
            Text('Reply to message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (parentMessage != null) ...[
            Container(
              color: Colors.grey[50],
              child: MessageBubble(message: parentMessage, chatType: chatType, chatId: chatId, showSender: true),
            ),
            Divider(height: 1, color: Colors.grey[200]),
          ],
          Expanded(
            child: threadsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (replies) => replies.isEmpty
                  ? const Center(child: Text('No replies yet'))
                  : ListView.builder(
                      itemCount: replies.length,
                      itemBuilder: (_, i) => MessageBubble(
                        message: replies[i],
                        chatType: chatType,
                        chatId: chatId,
                      ),
                    ),
            ),
          ),
          MessageInputBar(
            onSendText: (text) => ref.read(messageNotifierProvider.notifier).sendThreadMessage(
              chatType: chatType,
              chatId: chatId,
              messageId: messageId,
              content: text,
            ),
          ),
        ],
      ),
    );
  }
}
