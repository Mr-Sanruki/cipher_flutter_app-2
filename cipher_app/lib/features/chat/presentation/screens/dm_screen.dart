import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_lookup_provider.dart';
import '../../data/models/dm_model.dart';
import '../../data/models/message_model.dart';

class DmScreen extends ConsumerStatefulWidget {
  final String dmId;
  const DmScreen({super.key, required this.dmId});

  @override
  ConsumerState<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends ConsumerState<DmScreen> {
  ProviderSubscription<AsyncValue<List<MessageModel>>>? _messagesSub;

  @override
  void initState() {
    super.initState();

    final target = (chatType: 'dm', chatId: widget.dmId);
    _messagesSub = ref.listenManual<AsyncValue<List<MessageModel>>>(messagesProvider(target), (prev, next) {
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
          ref.read(messageNotifierProvider.notifier).markDelivered(chatType: 'dm', chatId: widget.dmId, messageIds: toDeliver);
        }
        if (toRead.isNotEmpty) {
          ref.read(messageNotifierProvider.notifier).markRead(chatType: 'dm', chatId: widget.dmId, messageIds: toRead);
        }
      });
    });
  }

  @override
  void dispose() {
    _messagesSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider((chatType: 'dm', chatId: widget.dmId)));
    final dmsAsync = ref.watch(dmsProvider);
    final myId = ref.watch(backendUserIdProvider);
    DmModel? dm;
    final dms = dmsAsync.value;
    if (dms != null) {
      for (final d in dms) {
        if (d.id == widget.dmId) {
          dm = d;
          break;
        }
      }
    }

    final dmFallbackAsync = (dm == null && myId != null)
        ? ref.watch(FutureProvider.autoDispose<DmModel>((ref) async {
            return ref.watch(chatRepositoryProvider).getDmById(dmId: widget.dmId);
          }))
        : const AsyncValue.data(null);
    final resolvedDm = dm ?? dmFallbackAsync.value;

    final otherId = (resolvedDm != null && myId != null) ? resolvedDm.otherUserId(myId) : '';
    final otherUserAsync = otherId.isNotEmpty ? ref.watch(userByIdProvider(otherId)) : const AsyncValue.data(null);
    final otherUser = otherUserAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              radius: 16,
              backgroundImage: otherUser?.avatarUrl != null && (otherUser!.avatarUrl ?? '').isNotEmpty
                  ? NetworkImage(otherUser.avatarUrl!)
                  : null,
              child: (otherUser?.avatarUrl == null || (otherUser!.avatarUrl ?? '').isEmpty)
                  ? Icon(Icons.person_outline, color: Colors.blue.shade700, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              otherUser?.name ?? otherId,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {
              context.push('/chat-search/dm/${widget.dmId}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              final currentDm = resolvedDm;
              if (myId == null || currentDm == null) return;
              final toUserId = currentDm.otherUserId(myId);
              ref.read(chatRepositoryProvider).sendCallInvite(toUserId: toUserId, callId: widget.dmId, callType: 'video');

              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const AlertDialog(title: Text('Calling...'), content: Text('Waiting for other user to accept')),
              );

              ref
                  .read(chatRepositoryProvider)
                  .callEvents()
                  .firstWhere((e) => e['callId'] == widget.dmId && e['fromUserId'] == toUserId)
                  .then((e) {
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
                if (e['event'] == 'accepted' && context.mounted) context.push('/video-call/${widget.dmId}');
              }).catchError((_) {
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
              });
            },
            tooltip: 'Video call',
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') {
                await ref.read(messageNotifierProvider.notifier).clearChat(chatType: 'dm', chatId: widget.dmId);
              }
              if (v == 'delete') {
                await ref.read(messageNotifierProvider.notifier).hideDm(dmId: widget.dmId);
                if (context.mounted) context.pop();
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
              PopupMenuItem(value: 'delete', child: Text('Delete chat')),
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
                  ? const Center(child: Text('Start a conversation!'))
                  : ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (_, i) => MessageBubble(message: messages[i], chatType: 'dm', chatId: widget.dmId),
                    ),
            ),
          ),
          MessageInputBar(
            onSendText: (text) => ref.read(messageNotifierProvider.notifier).sendMessage(
              chatType: 'dm',
              chatId: widget.dmId,
              content: text,
              type: MessageType.text,
            ),
            onSendFile: (file) => ref.read(messageNotifierProvider.notifier).sendFile(chatType: 'dm', chatId: widget.dmId, file: file),
          ),
        ],
      ),
    );
  }
}
