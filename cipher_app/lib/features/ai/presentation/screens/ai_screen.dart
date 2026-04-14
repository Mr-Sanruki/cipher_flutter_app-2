import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/ai_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/data/models/message_model.dart';

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
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
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
          if (!isUser)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: message.content));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                ),
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_outlined, size: 18),
                  onPressed: () async {
                    await Share.share(message.content);
                  },
                ),
                IconButton(
                  tooltip: 'Send to chat',
                  icon: const Icon(Icons.send_outlined, size: 18),
                  onPressed: () => _showSendToChatSheet(context, message.content),
                ),
              ],
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Future<void> _showSendToChatSheet(BuildContext context, String text) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Send to DM'),
              onTap: () {
                Navigator.pop(ctx);
                _showPickChatAndSend(context, text, chatType: 'dm');
              },
            ),
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Send to Channel'),
              onTap: () {
                Navigator.pop(ctx);
                _showPickChatAndSend(context, text, chatType: 'channel');
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Send to Group'),
              onTap: () {
                Navigator.pop(ctx);
                _showPickChatAndSend(context, text, chatType: 'group');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPickChatAndSend(BuildContext context, String text, {required String chatType}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        Widget body;
        if (chatType == 'dm') {
          final dmsAsync = ref.watch(dmsProvider);
          body = dmsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e'),
            ),
            data: (dms) => ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text('Pick a DM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                for (final dm in dms)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('DM'),
                    subtitle: Text(
                      dm.lastMessage != null && dm.lastMessage!.isNotEmpty
                          ? dm.lastMessage!
                          : dm.memberIds.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _sendToChat(context, text, chatType: 'dm', chatId: dm.id);
                    },
                  ),
              ],
            ),
          );
        } else if (chatType == 'channel') {
          final channelsAsync = ref.watch(channelsProvider);
          body = channelsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e'),
            ),
            data: (channels) => ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text('Pick a channel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                for (final c in channels)
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text('# ${c.name}'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _sendToChat(context, text, chatType: 'channel', chatId: c.id);
                    },
                  ),
              ],
            ),
          );
        } else {
          final groupsAsync = ref.watch(groupsProvider);
          body = groupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e'),
            ),
            data: (groups) => ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text('Pick a group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                for (final g in groups)
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(g.name),
                    subtitle: Text('${g.memberIds.length} members'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _sendToChat(context, text, chatType: 'group', chatId: g.id);
                    },
                  ),
              ],
            ),
          );
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
            child: body,
          ),
        );
      },
    );
  }

  Future<void> _sendToChat(BuildContext context, String text, {required String chatType, required String chatId}) async {
    try {
      await ref.read(messageNotifierProvider.notifier).sendMessage(
            chatType: chatType,
            chatId: chatId,
            content: text,
            type: MessageType.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
