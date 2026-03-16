import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory DmModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DmModel(
      id: doc.id,
      workspaceId: data['workspaceId'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'workspaceId': workspaceId,
    'memberIds': memberIds,
    'lastMessage': lastMessage,
    'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  String otherUserId(String myId) => memberIds.firstWhere((id) => id != myId);

  @override
  List<Object?> get props => [id, workspaceId, memberIds];
}
