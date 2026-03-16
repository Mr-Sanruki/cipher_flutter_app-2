import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/message_model.dart';

class DmScreen extends ConsumerWidget {
  final String dmId;
  const DmScreen({super.key, required this.dmId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(dmId));
    final dmsAsync = ref.watch(dmsProvider);
    final user = ref.watch(authStateProvider).value;
    final dm = dmsAsync.value?.firstWhere((d) => d.id == dmId, orElse: () => dmsAsync.value!.first);
    final otherId = dm?.otherUserId(user?.uid ?? '') ?? 'User';

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
            icon: const Icon(Icons.call_outlined),
            onPressed: () => context.push('/call/$dmId'),
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
                      itemBuilder: (_, i) => MessageBubble(message: messages[i], chatId: dmId),
                    ),
            ),
          ),
          MessageInputBar(
            onSendText: (text) => ref.read(messageNotifierProvider.notifier).sendMessage(
              chatId: dmId,
              content: text,
              type: MessageType.text,
            ),
            onSendFile: (file) => ref.read(messageNotifierProvider.notifier).sendFile(dmId, file),
          ),
        ],
      ),
    );
  }
}
