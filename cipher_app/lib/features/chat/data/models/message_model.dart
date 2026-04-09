import 'package:equatable/equatable.dart';

enum MessageType { text, image, file, video, audio, ai }

class ForwardOfModel extends Equatable {
  final String? messageId;
  final String? chatType;
  final String? chatId;
  final String? senderId;
  final String? content;
  final String? type;
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;
  final DateTime? createdAt;

  const ForwardOfModel({
    this.messageId,
    this.chatType,
    this.chatId,
    this.senderId,
    this.content,
    this.type,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.createdAt,
  });

  factory ForwardOfModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    return ForwardOfModel(
      messageId: json['messageId']?.toString(),
      chatType: json['chatType']?.toString(),
      chatId: json['chatId']?.toString(),
      senderId: json['senderId']?.toString(),
      content: json['content']?.toString(),
      type: json['type']?.toString(),
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSize: json['fileSize']?.toString(),
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'chatType': chatType,
        'chatId': chatId,
        'senderId': senderId,
        'content': content,
        'type': type,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [messageId, chatType, chatId, senderId, content, type, fileUrl, fileName, fileSize, createdAt];
}

class MessageModel extends Equatable {
  final String id;
  final String? chatType;
  final String? chatId;
  final String? parentMessageId;
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
  final DateTime? pinnedAt;
  final String? pinnedBy;
  final int threadCount;
  final Map<String, DateTime> deliveredTo;
  final Map<String, DateTime> readBy;
  final Map<String, List<String>> reactions;
  final ForwardOfModel? forwardOf;
  final DateTime createdAt;
  final DateTime? editedAt;

  const MessageModel({
    required this.id,
    this.chatType,
    this.chatId,
    this.parentMessageId,
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
    this.pinnedAt,
    this.pinnedBy,
    this.threadCount = 0,
    this.deliveredTo = const {},
    this.readBy = const {},
    this.reactions = const {},
    this.forwardOf,
    required this.createdAt,
    this.editedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) return DateTime.parse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    Map<String, DateTime> parseMap(dynamic m) {
      if (m is! Map) return const {};
      return m.map((k, v) => MapEntry(k.toString(), parseDate(v)));
    }

    Map<String, List<String>> parseReactions(dynamic m) {
      if (m is! Map) return const {};
      final out = <String, List<String>>{};
      for (final e in m.entries) {
        final key = e.key.toString();
        final v = e.value;
        if (v is List) {
          out[key] = v.map((x) => x.toString()).toList();
        }
      }
      return out;
    }

    return MessageModel(
      id: (json['id'] ?? '').toString(),
      chatType: json['chatType']?.toString(),
      chatId: json['chatId']?.toString(),
      parentMessageId: json['parentMessageId']?.toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      senderAvatar: json['senderAvatar']?.toString(),
      content: (json['content'] ?? '').toString(),
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] ?? '').toString(),
        orElse: () => MessageType.text,
      ),
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSize: json['fileSize']?.toString(),
      isEdited: json['isEdited'] == true,
      isDeleted: json['isDeleted'] == true,
      pinnedAt: json['pinnedAt'] != null ? parseDate(json['pinnedAt']) : null,
      pinnedBy: json['pinnedBy']?.toString(),
      threadCount: (json['threadCount'] is num) ? (json['threadCount'] as num).toInt() : 0,
      deliveredTo: parseMap(json['deliveredTo']),
      readBy: parseMap(json['readBy']),
      reactions: parseReactions(json['reactions']),
      forwardOf: (json['forwardOf'] is Map)
          ? ForwardOfModel.fromJson(Map<String, dynamic>.from(json['forwardOf'] as Map))
          : null,
      createdAt: parseDate(json['createdAt']),
      editedAt: json['editedAt'] != null ? parseDate(json['editedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatType': chatType,
    'chatId': chatId,
    'parentMessageId': parentMessageId,
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
    'pinnedAt': pinnedAt?.toUtc().toIso8601String(),
    'pinnedBy': pinnedBy,
    'threadCount': threadCount,
    'deliveredTo': deliveredTo.map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
    'readBy': readBy.map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
    'reactions': reactions,
    'forwardOf': forwardOf?.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'editedAt': editedAt?.toUtc().toIso8601String(),
  };

  MessageModel copyWith({
    String? content,
    bool? isEdited,
    bool? isDeleted,
    DateTime? pinnedAt,
    String? pinnedBy,
    int? threadCount,
    Map<String, DateTime>? deliveredTo,
    Map<String, DateTime>? readBy,
    Map<String, List<String>>? reactions,
    ForwardOfModel? forwardOf,
    DateTime? editedAt,
  }) => MessageModel(
    id: id,
    chatType: chatType,
    chatId: chatId,
    parentMessageId: parentMessageId,
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
    pinnedAt: pinnedAt ?? this.pinnedAt,
    pinnedBy: pinnedBy ?? this.pinnedBy,
    threadCount: threadCount ?? this.threadCount,
    deliveredTo: deliveredTo ?? this.deliveredTo,
    readBy: readBy ?? this.readBy,
    reactions: reactions ?? this.reactions,
    forwardOf: forwardOf ?? this.forwardOf,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
  );

  @override
  List<Object?> get props => [id, chatType, chatId, parentMessageId, senderId, content, isEdited, isDeleted, pinnedAt, pinnedBy, deliveredTo, readBy, reactions, forwardOf];
}
