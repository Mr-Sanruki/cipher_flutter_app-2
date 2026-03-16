import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ChannelModel extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String? description;
  final String createdBy;
  final bool isAnnouncement;
  final DateTime createdAt;

  const ChannelModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.description,
    required this.createdBy,
    this.isAnnouncement = false,
    required this.createdAt,
  });

  factory ChannelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChannelModel(
      id: doc.id,
      workspaceId: data['workspaceId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      isAnnouncement: data['isAnnouncement'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'workspaceId': workspaceId,
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'isAnnouncement': isAnnouncement,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  @override
  List<Object?> get props => [id, workspaceId, name];
}
