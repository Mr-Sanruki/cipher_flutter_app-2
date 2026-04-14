import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/message_model.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../../../core/config/app_config_provider.dart';

class MessageBubble extends ConsumerWidget {
  final MessageModel message;
  final String chatId;
  final String chatType;
  final bool showSender;
  final bool inThreadView;

  const MessageBubble({
    super.key,
    required this.message,
    required this.chatId,
    required this.chatType,
    this.showSender = true,
    this.inThreadView = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(backendUserIdProvider);
    final isMe = myId != null && message.senderId == myId;
    final cs = Theme.of(context).colorScheme;
    final cfg = ref.watch(appConfigProvider);

    String? resolveUrl(String? raw) {
      final u = (raw ?? '').trim();
      if (u.isEmpty) return null;
      final uri = Uri.tryParse(u);
      if (uri == null) return null;
      if (uri.hasScheme) return u;
      final base = cfg.backendBaseUrl.trim();
      if (base.isEmpty) return u;
      if (u.startsWith('/')) return '$base$u';
      return '$base/$u';
    }
    final hasThread = message.parentMessageId == null && message.threadCount > 0;
    final isThreadParentInMainChat = hasThread && !inThreadView;

    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          '🚫 This message was deleted',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.55),
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        ),
      );
    }

    final bubbleColor = isMe
        ? (isThreadParentInMainChat ? cs.primary.withValues(alpha: 0.92) : cs.primary)
        : (isThreadParentInMainChat ? cs.surfaceContainerHighest.withValues(alpha: 0.85) : cs.surfaceContainerHighest);

    final bubbleBorder = isThreadParentInMainChat
        ? Border.all(color: cs.primary.withValues(alpha: 0.55), width: 1.2)
        : (!isMe ? Border.all(color: cs.outline.withValues(alpha: 0.45)) : null);
    final textColor = isMe ? cs.onPrimary : cs.onSurface;
    final metaColor = cs.onSurface.withValues(alpha: 0.55);
    final contentWidget = _buildContent(context, isMe, textColor, resolveUrl: resolveUrl);

    return GestureDetector(
      onTap: hasThread
          ? () => context.push(
                '/thread/${message.id}',
                extra: {'chatType': chatType, 'chatId': chatId, 'message': message},
              )
          : null,
      onLongPress: () => _showMessageOptions(context, ref, isMe),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          decoration: null,
          padding: EdgeInsets.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage: message.senderAvatar != null
                      ? CachedNetworkImageProvider(message.senderAvatar!)
                      : null,
                  child: message.senderAvatar == null
                      ? Text(message.senderName[0].toUpperCase(),
                          style: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (showSender && !isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        border: bubbleBorder,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                          bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isThreadParentInMainChat) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.forum_outlined, size: 14, color: isMe ? cs.onPrimary : cs.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Thread',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isMe ? cs.onPrimary : cs.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (message.forwardOf != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? cs.onPrimary.withValues(alpha: 0.14)
                                    : cs.onSurface.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Forwarded',
                                    style: TextStyle(
                                      color: isMe ? cs.onPrimary.withValues(alpha: 0.75) : metaColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (message.forwardOf?.content ?? '').toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          contentWidget,
                        ],
                      ),
                    ),
                  if (message.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _ReactionsRow(
                        reactions: message.reactions,
                        myId: myId,
                        isMe: isMe,
                        onTap: (emoji) => ref.read(messageNotifierProvider.notifier).toggleReaction(
                              chatType: chatType,
                              chatId: chatId,
                              messageId: message.id,
                              emoji: emoji,
                            ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.pinnedAt != null) ...[
                        Icon(Icons.push_pin, size: 14, color: metaColor),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        timeago.format(message.createdAt),
                        style: TextStyle(color: metaColor, fontSize: 11),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Icon(
                          _receiptIcon(myId),
                          size: 14,
                          color: _receiptColor(myId),
                        ),
                      ],
                      if (message.isEdited) ...[
                        const SizedBox(width: 4),
                        Text('(edited)',
                            style: TextStyle(color: metaColor, fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                  if (hasThread)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          'View thread • ${message.threadCount} ${message.threadCount == 1 ? 'reply' : 'replies'}',
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isMe,
    Color textColor, {
    required String? Function(String?) resolveUrl,
  }) {
    final cs = Theme.of(context).colorScheme;

    switch (message.type) {
      case MessageType.image:
        return InkWell(
          onTap: () async {
            final url = resolveUrl(message.fileUrl);
            if (url == null || url.isEmpty) return;
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            final ok = await canLaunchUrl(uri);
            if (!ok) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open this file')));
              }
              return;
            }
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: resolveUrl(message.fileUrl) ?? '',
              width: 200,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                  height: 120, child: Center(child: CircularProgressIndicator())),
            ),
          ),
        );
      case MessageType.file:
      case MessageType.video:
      case MessageType.audio:
        return InkWell(
          onTap: () async {
            final url = resolveUrl(message.fileUrl);
            if (url == null || url.isEmpty) return;
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            final ok = await canLaunchUrl(uri);
            if (!ok) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open this file')));
              }
              return;
            }
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_fileIcon(message.type), color: isMe ? cs.onPrimary.withValues(alpha: 0.8) : cs.onSurface.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message.fileName ?? message.content,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    if (message.fileSize != null)
                      Text(message.fileSize!,
                          style: TextStyle(color: isMe ? cs.onPrimary.withValues(alpha: 0.7) : cs.onSurface.withValues(alpha: 0.55), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return Text(message.content, style: TextStyle(color: textColor, fontSize: 15));
    }
  }

  IconData _fileIcon(MessageType type) {
    switch (type) {
      case MessageType.video: return Icons.video_file_outlined;
      case MessageType.audio: return Icons.audio_file_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  IconData _receiptIcon(String? currentUserId) {
    if (currentUserId == null) return Icons.check;

    final deliveredCount = message.deliveredTo.length;
    final readCount = message.readBy.length;
    final othersDelivered = deliveredCount > 1;
    final othersRead = readCount > 1;

    if (othersRead) return Icons.done_all;
    if (othersDelivered) return Icons.done_all;
    return Icons.check;
  }

  Color _receiptColor(String? currentUserId) {
    if (currentUserId == null) return Colors.grey;

    final readCount = message.readBy.length;
    final othersRead = readCount > 1;

    if (othersRead) return const Color(0xFF6C63FF);
    return Colors.grey;
  }

  void _showMessageOptions(BuildContext context, WidgetRef ref, bool isMe) {
    final myId = ref.read(backendUserIdProvider);
    final workspace = ref.read(selectedWorkspaceProvider);
    final canPin = chatType != 'channel' || (workspace?.isAdmin(myId ?? '') ?? false);

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canPin)
              ListTile(
                leading: Icon(message.pinnedAt != null ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(message.pinnedAt != null ? 'Unpin' : 'Pin'),
                onTap: () {
                  Navigator.pop(context);
                  if (message.pinnedAt != null) {
                    ref.read(messageNotifierProvider.notifier).unpinMessage(
                          chatType: chatType,
                          chatId: chatId,
                          messageId: message.id,
                        );
                  } else {
                    ref.read(messageNotifierProvider.notifier).pinMessage(
                          chatType: chatType,
                          chatId: chatId,
                          messageId: message.id,
                        );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('React'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward_outlined),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                _showForwardPicker(context, ref);
              },
            ),
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  _showReportPicker(context, ref);
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply in thread'),
              onTap: () {
                Navigator.pop(context);
                context.push('/thread/${message.id}',
                    extra: {'chatType': chatType, 'chatId': chatId, 'message': message});
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                SharePlus.instance.share(ShareParams(text: message.content));
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(messageNotifierProvider.notifier)
                      .deleteMessage(chatType: chatType, chatId: chatId, messageId: message.id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(controller: ctrl, maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(messageNotifierProvider.notifier)
                  .editMessage(chatId, message.id, ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReportPicker(BuildContext context, WidgetRef ref) {
    const reasons = [
      'Spam',
      'Harassment',
      'Hate speech',
      'Explicit content',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('Report message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final r in reasons)
              ListTile(
                title: Text(r),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(messageNotifierProvider.notifier).reportMessage(
                        chatType: chatType,
                        chatId: chatId,
                        messageId: message.id,
                        reason: r,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported')));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context, WidgetRef ref) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Wrap(
            spacing: 10,
            children: [
              for (final e in emojis)
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(messageNotifierProvider.notifier).toggleReaction(
                          chatType: chatType,
                          chatId: chatId,
                          messageId: message.id,
                          emoji: e,
                        );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForwardPicker(BuildContext context, WidgetRef ref) {
    final channels = ref.read(channelsProvider).value ?? const [];
    final groups = ref.read(groupsProvider).value ?? const [];
    final dms = ref.read(dmsProvider).value ?? const [];

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Forward to this chat'),
              onTap: () {
                Navigator.pop(context);
                ref.read(messageNotifierProvider.notifier).forwardMessage(
                      sourceChatType: chatType,
                      sourceChatId: chatId,
                      messageId: message.id,
                      targetChatType: chatType,
                      targetChatId: chatId,
                    );
              },
            ),
            if (channels.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Channels', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            for (final c in channels)
              ListTile(
                title: Text('# ${c.name}'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(messageNotifierProvider.notifier).forwardMessage(
                        sourceChatType: chatType,
                        sourceChatId: chatId,
                        messageId: message.id,
                        targetChatType: 'channel',
                        targetChatId: c.id,
                      );
                },
              ),
            if (groups.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Groups', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            for (final g in groups)
              ListTile(
                title: Text(g.name),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(messageNotifierProvider.notifier).forwardMessage(
                        sourceChatType: chatType,
                        sourceChatId: chatId,
                        messageId: message.id,
                        targetChatType: 'group',
                        targetChatId: g.id,
                      );
                },
              ),
            if (dms.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Direct messages', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            for (final d in dms)
              ListTile(
                title: Text('DM ${d.id.substring(0, 6)}'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(messageNotifierProvider.notifier).forwardMessage(
                        sourceChatType: chatType,
                        sourceChatId: chatId,
                        messageId: message.id,
                        targetChatType: 'dm',
                        targetChatId: d.id,
                      );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String? myId;
  final bool isMe;
  final void Function(String emoji) onTap;

  const _ReactionsRow({
    required this.reactions,
    required this.myId,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in entries)
          InkWell(
            onTap: () => onTap(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _bgFor(e, isMe),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _borderFor(e, isMe, myId)),
              ),
              child: Text(
                '${e.key} ${e.value.length}',
                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Color _bgFor(MapEntry<String, List<String>> e, bool isMe) {
    if (isMe) return const Color(0xFF6C63FF);
    return Colors.grey[100]!;
  }

  Color _borderFor(MapEntry<String, List<String>> e, bool isMe, String? myId) {
    final has = myId != null && e.value.any((x) => x == myId);
    if (!has) return Colors.transparent;
    return isMe ? Colors.white.withAlpha(180) : const Color(0xFF6C63FF);
  }
}
