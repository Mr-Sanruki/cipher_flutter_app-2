import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_provider.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(aiMessagesProvider.notifier).sendMessage(text, ref);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiMessagesProvider);
    final isLoading = ref.watch(aiLoadingProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: cs.primary),
            const SizedBox(width: 8),
            const Text('AI Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref.read(aiMessagesProvider.notifier).clearHistory(),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildWelcome(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == messages.length) return _buildTyping();
                      return _buildMessage(context, messages[i]);
                    },
                  ),
          ),
          _buildInput(context),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 56, color: cs.primary),
                  const SizedBox(height: 12),
                  const Text('AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Powered by Groq', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      'Summarize a topic',
                      'Write an email',
                      'Explain code',
                      'Brainstorm ideas',
                    ]
                        .map(
                          (s) => ActionChip(
                            label: Text(s),
                            onPressed: () {
                              _controller.text = s;
                              _send();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context, AiMessage message) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final bubbleColor = isUser ? cs.primary : cs.surfaceContainerHighest;
    final bubbleBorder = !isUser ? Border.all(color: cs.outline.withValues(alpha: 0.45)) : null;
    final textColor = isUser ? cs.onPrimary : cs.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: bubbleBorder,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: textColor, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildTyping() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40, height: 20,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          SizedBox(width: 8),
          Text('Thinking...', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    ),
  );

  Widget _buildInput(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = cs.outline.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _send,
              icon: Icon(Icons.send_rounded, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}
