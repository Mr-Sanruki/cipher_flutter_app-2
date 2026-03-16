import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../models/channel_model.dart';
import '../models/group_model.dart';
import '../models/dm_model.dart';
import '../../../../core/constants/app_constants.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

class ChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─── Channels ───────────────────────────────────────────────
  Future<ChannelModel> createChannel({
    required String workspaceId,
    required String name,
    required String createdBy,
    String? description,
    bool isAnnouncement = false,
  }) async {
    final ref = _db.collection(AppConstants.channelsCollection).doc();
    final channel = ChannelModel(
      id: ref.id, workspaceId: workspaceId, name: name,
      description: description, createdBy: createdBy,
      isAnnouncement: isAnnouncement, createdAt: DateTime.now(),
    );
    await ref.set(channel.toFirestore());
    return channel;
  }

  Stream<List<ChannelModel>> getChannels(String workspaceId) => _db
      .collection(AppConstants.channelsCollection)
      .where('workspaceId', isEqualTo: workspaceId)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ChannelModel.fromFirestore).toList());

  // ─── Groups ──────────────────────────────────────────────────
  Future<GroupModel> createGroup({
    required String workspaceId,
    required String name,
    required String createdBy,
    required List<String> memberIds,
  }) async {
    final ref = _db.collection(AppConstants.groupsCollection).doc();
    final group = GroupModel(
      id: ref.id, workspaceId: workspaceId, name: name,
      createdBy: createdBy,
      memberIds: [...memberIds, createdBy],
      createdAt: DateTime.now(),
    );
    await ref.set(group.toFirestore());
    return group;
  }

  Stream<List<GroupModel>> getGroups(String workspaceId, String userId) => _db
      .collection(AppConstants.groupsCollection)
      .where('workspaceId', isEqualTo: workspaceId)
      .where('memberIds', arrayContains: userId)
      .snapshots()
      .map((s) => s.docs.map(GroupModel.fromFirestore).toList());

  // ─── DMs ─────────────────────────────────────────────────────
  Future<DmModel> getOrCreateDm({
    required String workspaceId,
    required String userId1,
    required String userId2,
  }) async {
    final ids = [userId1, userId2]..sort();
    final query = await _db.collection(AppConstants.dmsCollection)
        .where('workspaceId', isEqualTo: workspaceId)
        .where('memberIds', isEqualTo: ids)
        .limit(1).get();
    if (query.docs.isNotEmpty) return DmModel.fromFirestore(query.docs.first);
    final ref = _db.collection(AppConstants.dmsCollection).doc();
    final dm = DmModel(
      id: ref.id, workspaceId: workspaceId,
      memberIds: ids, createdAt: DateTime.now(),
    );
    await ref.set(dm.toFirestore());
    return dm;
  }

  Stream<List<DmModel>> getDms(String workspaceId, String userId) => _db
      .collection(AppConstants.dmsCollection)
      .where('workspaceId', isEqualTo: workspaceId)
      .where('memberIds', arrayContains: userId)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(DmModel.fromFirestore).toList());

  // ─── Messages ────────────────────────────────────────────────
  String _msgPath(String chatId) => 'chats/$chatId/messages';

  Stream<List<MessageModel>> getMessages(String chatId) => _db
      .collection(_msgPath(chatId))
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(MessageModel.fromFirestore).toList());

  Future<MessageModel> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String content,
    MessageType type = MessageType.text,
    String? fileUrl,
    String? fileName,
    String? fileSize,
  }) async {
    final ref = _db.collection(_msgPath(chatId)).doc();
    final message = MessageModel(
      id: ref.id, senderId: senderId, senderName: senderName,
      senderAvatar: senderAvatar, content: content, type: type,
      fileUrl: fileUrl, fileName: fileName, fileSize: fileSize,
      createdAt: DateTime.now(),
    );
    await ref.set(message.toFirestore());
    await _db.doc('chats/$chatId').set({
      'lastMessage': content, 'lastMessageAt': Timestamp.now(),
    }, SetOptions(merge: true));
    return message;
  }

  Future<void> editMessage(String chatId, String messageId, String newContent) async {
    await _db.collection(_msgPath(chatId)).doc(messageId).update({
      'content': newContent,
      'isEdited': true,
      'editedAt': Timestamp.now(),
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _db.collection(_msgPath(chatId)).doc(messageId).update({
      'isDeleted': true,
      'content': 'This message was deleted',
    });
  }

  // ─── Threads ─────────────────────────────────────────────────
  Stream<List<MessageModel>> getThreadMessages(String chatId, String messageId) => _db
      .collection('chats/$chatId/messages/$messageId/threads')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(MessageModel.fromFirestore).toList());

  Future<void> sendThreadMessage({
    required String chatId,
    required String messageId,
    required MessageModel message,
  }) async {
    final ref = _db
        .collection('chats/$chatId/messages/$messageId/threads')
        .doc();
    await ref.set(message.copyWith().toFirestore());
    await _db.collection(_msgPath(chatId)).doc(messageId).update({
      'threadCount': FieldValue.increment(1),
    });
  }

  // ─── File Upload ─────────────────────────────────────────────
  Future<String> uploadFile(File file, String chatId) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = _storage.ref('${AppConstants.chatFiles}/$chatId/$fileName');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> uploadImage(File image, String chatId) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('${AppConstants.chatImages}/$chatId/$fileName');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }
}
