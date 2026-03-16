import 'package:equatable/equatable.dart';

class DmModel extends Equatable {
  final String id;
  final String workspaceId;
  final List<String> memberIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  const DmModel({
    required this.id,
    required this.workspaceId,
    required this.memberIds,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory DmModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.parse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    return DmModel(
      id: (json['id'] ?? '').toString(),
      workspaceId: (json['workspaceId'] ?? '').toString(),
      memberIds: (json['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      lastMessage: json['lastMessage']?.toString(),
      lastMessageAt: parseDate(json['lastMessageAt']),
      createdAt: parseDate(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'memberIds': memberIds,
    'lastMessage': lastMessage,
    'lastMessageAt': lastMessageAt?.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  String otherUserId(String myId) => memberIds.firstWhere((id) => id != myId);

  @override
  List<Object?> get props => [id, workspaceId, memberIds];
}
