import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class WorkspaceModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String ownerId;
  final List<String> memberIds;
  final List<String> adminIds;
  final String inviteCode;
  final DateTime createdAt;

  const WorkspaceModel({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.ownerId,
    this.memberIds = const [],
    this.adminIds = const [],
    required this.inviteCode,
    required this.createdAt,
  });

  factory WorkspaceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkspaceModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      iconUrl: data['iconUrl'],
      ownerId: data['ownerId'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      adminIds: List<String>.from(data['adminIds'] ?? []),
      inviteCode: data['inviteCode'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'iconUrl': iconUrl,
    'ownerId': ownerId,
    'memberIds': memberIds,
    'adminIds': adminIds,
    'inviteCode': inviteCode,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  bool isAdmin(String userId) => adminIds.contains(userId) || ownerId == userId;

  WorkspaceModel copyWith({
    String? name,
    String? description,
    String? iconUrl,
    List<String>? memberIds,
    List<String>? adminIds,
  }) => WorkspaceModel(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    iconUrl: iconUrl ?? this.iconUrl,
    ownerId: ownerId,
    memberIds: memberIds ?? this.memberIds,
    adminIds: adminIds ?? this.adminIds,
    inviteCode: inviteCode,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, name, ownerId, inviteCode];
}
