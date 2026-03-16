import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class GroupModel extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String? iconUrl;
  final String createdBy;
  final List<String> memberIds;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.iconUrl,
    required this.createdBy,
    this.memberIds = const [],
    required this.createdAt,
  });

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      workspaceId: data['workspaceId'] ?? '',
      name: data['name'] ?? '',
      iconUrl: data['iconUrl'],
      createdBy: data['createdBy'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'workspaceId': workspaceId,
    'name': name,
    'iconUrl': iconUrl,
    'createdBy': createdBy,
    'memberIds': memberIds,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  @override
  List<Object?> get props => [id, workspaceId, name];
}
