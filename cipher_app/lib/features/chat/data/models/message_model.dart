import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MessageType { text, image, file, video, audio, ai }

class MessageModel extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;
  final bool isEdited;
  final bool isDeleted;
  final int threadCount;
  final DateTime createdAt;
  final DateTime? editedAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = MessageType.text,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isEdited = false,
    this.isDeleted = false,
    this.threadCount = 0,
    required this.createdAt,
    this.editedAt,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderAvatar: data['senderAvatar'],
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      fileSize: data['fileSize'],
      isEdited: data['isEdited'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      threadCount: data['threadCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      editedAt: data['editedAt'] != null ? (data['editedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'content': content,
    'type': type.name,
    'fileUrl': fileUrl,
    'fileName': fileName,
    'fileSize': fileSize,
    'isEdited': isEdited,
    'isDeleted': isDeleted,
    'threadCount': threadCount,
    'createdAt': Timestamp.fromDate(createdAt),
    'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
  };

  MessageModel copyWith({
    String? content,
    bool? isEdited,
    bool? isDeleted,
    int? threadCount,
    DateTime? editedAt,
  }) => MessageModel(
    id: id,
    senderId: senderId,
    senderName: senderName,
    senderAvatar: senderAvatar,
    content: content ?? this.content,
    type: type,
    fileUrl: fileUrl,
    fileName: fileName,
    fileSize: fileSize,
    isEdited: isEdited ?? this.isEdited,
    isDeleted: isDeleted ?? this.isDeleted,
    threadCount: threadCount ?? this.threadCount,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
  );

  @override
  List<Object?> get props => [id, senderId, content, isEdited, isDeleted];
}
