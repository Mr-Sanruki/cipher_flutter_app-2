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
    final cs = Theme.of(context).colorScheme;
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
          decoration: InputDecoration(
            hintText: 'Search messages...',
            prefixIcon: Icon(Icons.search, color: cs.onSurface.withValues(alpha: 0.65)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: q.trim().isEmpty
          ? Center(
              child: Text(
                'Type to search',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            )
          : resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No results',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                    ),
                  );
                }
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
