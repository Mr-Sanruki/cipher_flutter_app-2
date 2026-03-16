import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/message_model.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MessageBubble extends ConsumerWidget {
  final MessageModel message;
  final String chatId;
  final bool showSender;

  const MessageBubble({
    super.key,
    required this.message,
    required this.chatId,
    this.showSender = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    final isMe = message.senderId == currentUser?.uid;

    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text('🚫 This message was deleted',
            style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic, fontSize: 13)),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context, ref, isMe),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF6C63FF),
                backgroundImage: message.senderAvatar != null
                    ? CachedNetworkImageProvider(message.senderAvatar!)
                    : null,
                child: message.senderAvatar == null
                    ? Text(message.senderName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12))
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
                      child: Text(message.senderName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF6C63FF) : Colors.grey[100],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: _buildContent(context, isMe),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeago.format(message.createdAt),
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                      if (message.isEdited) ...[
                        const SizedBox(width: 4),
                        Text('(edited)',
                            style: TextStyle(color: Colors.grey[400], fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                  if (message.threadCount > 0)
                    GestureDetector(
                      onTap: () => context.push('/thread/${message.id}',
                          extra: {'chatId': chatId, 'message': message}),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '💬 ${message.threadCount} ${message.threadCount == 1 ? 'reply' : 'replies'}',
                          style: const TextStyle(
                              color: Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isMe) {
    final textColor = isMe ? Colors.white : Colors.black87;
    switch (message.type) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: message.fileUrl ?? '',
            width: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator())),
          ),
        );
      case MessageType.file:
      case MessageType.video:
      case MessageType.audio:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_fileIcon(message.type), color: isMe ? Colors.white70 : Colors.grey[600], size: 20),
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
                        style: TextStyle(color: isMe ? Colors.white60 : Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
          ],
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

  void _showMessageOptions(BuildContext context, WidgetRef ref, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply in thread'),
              onTap: () {
                Navigator.pop(context);
                context.push('/thread/${message.id}',
                    extra: {'chatId': chatId, 'message': message});
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
                      .deleteMessage(chatId, message.id);
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
}
