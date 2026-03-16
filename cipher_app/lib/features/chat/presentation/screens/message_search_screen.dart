import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

class MessageSearchScreen extends ConsumerStatefulWidget {
  final String chatType;
  final String chatId;

  const MessageSearchScreen({
    super.key,
    required this.chatType,
    required this.chatId,
  });

  @override
  ConsumerState<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends ConsumerState<MessageSearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _ctrl.text;
    final resultsAsync = ref.watch(messageSearchProvider((
      chatType: widget.chatType,
      chatId: widget.chatId,
      query: q,
    )));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search messages...',
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: q.trim().isEmpty
          ? const Center(child: Text('Type to search'))
          : resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('No results'));
                return ListView.builder(
                  reverse: false,
                  itemCount: items.length,
                  itemBuilder: (_, i) => MessageBubble(
                    message: items[i],
                    chatType: widget.chatType,
                    chatId: widget.chatId,
                  ),
                );
              },
            ),
    );
  }
}
