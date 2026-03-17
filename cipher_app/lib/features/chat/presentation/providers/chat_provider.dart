import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message_model.dart';
import '../../data/models/channel_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/dm_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';

typedef ChatTarget = ({String chatType, String chatId});

// ─── Channels ───────────────────────────────────────────────────
final channelsProvider = StreamProvider<List<ChannelModel>>((ref) {
  final ws = ref.watch(selectedWorkspaceProvider);
  if (ws == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).getChannels(ws.id);
});

// ─── Groups ─────────────────────────────────────────────────────
final groupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final ws = ref.watch(selectedWorkspaceProvider);
  final token = ref.watch(authTokenProvider);
  if (ws == null || token == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).getGroups(ws.id);
});

// ─── DMs ────────────────────────────────────────────────────────
final dmsProvider = StreamProvider<List<DmModel>>((ref) {
  final ws = ref.watch(selectedWorkspaceProvider);
  final token = ref.watch(authTokenProvider);
  if (ws == null || token == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).getDms(ws.id);
});

// ─── Messages ───────────────────────────────────────────────────
final messagesProvider = StreamProvider.family<List<MessageModel>, ChatTarget>((ref, target) {
  return ref.watch(chatRepositoryProvider).getMessages(chatType: target.chatType, chatId: target.chatId);
});

final messageSearchProvider = FutureProvider.family<List<MessageModel>, ({String chatType, String chatId, String query})>((ref, args) async {
  if (args.query.trim().isEmpty) return [];
  return ref
      .watch(chatRepositoryProvider)
      .searchMessages(chatType: args.chatType, chatId: args.chatId, query: args.query.trim());
});

final threadMessagesProvider =
    StreamProvider.family<List<MessageModel>, ({String chatType, String chatId, String messageId})>((ref, args) {
  return ref.watch(chatRepositoryProvider).getThreadMessages(
    chatType: args.chatType,
    chatId: args.chatId,
    messageId: args.messageId,
  );
});

// ─── Message Notifier ───────────────────────────────────────────
final messageNotifierProvider =
    StateNotifierProvider<MessageNotifier, AsyncValue<void>>((ref) {
  return MessageNotifier(ref.watch(chatRepositoryProvider), ref);
});

class MessageNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repo;
  final Ref _ref;
  MessageNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> markDelivered({required String chatType, required String chatId, required List<String> messageIds}) async {
    await _repo.markDelivered(chatType: chatType, chatId: chatId, messageIds: messageIds);
  }

  Future<void> markRead({required String chatType, required String chatId, required List<String> messageIds}) async {
    await _repo.markRead(chatType: chatType, chatId: chatId, messageIds: messageIds);
  }

  Future<void> sendMessage({
    required String chatType,
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
    String? fileUrl,
    String? fileName,
    String? fileSize,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final userModel = await _ref.read(authRepositoryProvider).getCurrentUser();
      await _repo.sendMessage(
        chatType: chatType,
        chatId: chatId,
        senderName: userModel?.name ?? 'User',
        senderAvatar: userModel?.avatarUrl,
        content: content,
        type: type,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );
    });
  }

  Future<void> sendFile({required String chatType, required String chatId, required File file}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final userModel = await _ref.read(authRepositoryProvider).getCurrentUser();
      final fileName = file.path.split('/').last;
      final fileSize = '${(await file.length() / 1024).toStringAsFixed(1)} KB';
      final fileUrl = await _repo.uploadFile(file, chatId);
      final ext = fileName.split('.').last.toLowerCase();
      final type = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)
          ? MessageType.image
          : ['mp4', 'mov', 'avi'].contains(ext)
              ? MessageType.video
              : ['mp3', 'aac', 'wav'].contains(ext)
                  ? MessageType.audio
                  : MessageType.file;
      await _repo.sendMessage(
        chatType: chatType,
        chatId: chatId,
        senderName: userModel?.name ?? 'User',
        senderAvatar: userModel?.avatarUrl,
        content: fileName,
        type: type,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );
    });
  }

  Future<void> editMessage(String chatId, String messageId, String content) async {
    state = await AsyncValue.guard(() => _repo.editMessage(chatId, messageId, content));
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    state = await AsyncValue.guard(
      () => _repo.deleteMessage(chatType: 'dm', chatId: chatId, messageId: messageId),
    );
  }

  Future<void> toggleReaction({
    required String chatType,
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    state = await AsyncValue.guard(() async {
      await _repo.toggleReaction(chatType: chatType, chatId: chatId, messageId: messageId, emoji: emoji);
    });
  }

  Future<void> forwardMessage({
    required String sourceChatType,
    required String sourceChatId,
    required String messageId,
    required String targetChatType,
    required String targetChatId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final userModel = await _ref.read(authRepositoryProvider).getCurrentUser();
      await _repo.forwardMessage(
        sourceChatType: sourceChatType,
        sourceChatId: sourceChatId,
        messageId: messageId,
        targetChatType: targetChatType,
        targetChatId: targetChatId,
        senderName: userModel?.name ?? 'User',
        senderAvatar: userModel?.avatarUrl,
      );
    });
  }

  Future<void> sendThreadMessage({
    required String chatType,
    required String chatId,
    required String messageId,
    required String content,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final userModel = await _ref.read(authRepositoryProvider).getCurrentUser();
      final msg = MessageModel(
        id: '', senderId: '',
        senderName: userModel?.name ?? 'User',
        senderAvatar: userModel?.avatarUrl,
        content: content, createdAt: DateTime.now(),
      );
      await _repo.sendThreadMessage(chatType: chatType, chatId: chatId, messageId: messageId, message: msg);
    });
  }
}

// ─── Channel/Group Notifier ─────────────────────────────────────
final chatSetupNotifierProvider =
    StateNotifierProvider<ChatSetupNotifier, AsyncValue<void>>((ref) {
  return ChatSetupNotifier(ref.watch(chatRepositoryProvider), ref);
});

class ChatSetupNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repo;
  final Ref _ref;
  ChatSetupNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<ChannelModel?> createChannel(String name, {bool isAnnouncement = false, String? description}) async {
    state = const AsyncValue.loading();
    ChannelModel? channel;
    state = await AsyncValue.guard(() async {
      final ws = _ref.read(selectedWorkspaceProvider)!;
      channel = await _repo.createChannel(
        workspaceId: ws.id, name: name,
        description: description,
        isAnnouncement: isAnnouncement,
      );
    });
    return channel;
  }

  Future<GroupModel?> createGroup(String name, List<String> memberIds) async {
    state = const AsyncValue.loading();
    GroupModel? group;
    state = await AsyncValue.guard(() async {
      final ws = _ref.read(selectedWorkspaceProvider)!;
      group = await _repo.createGroup(
        workspaceId: ws.id, name: name,
        memberIds: memberIds,
      );
    });
    return group;
  }
}
