import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final List<String> workspaceIds;
  final bool notificationsEnabled;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.workspaceIds = const [],
    this.notificationsEnabled = true,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      avatarUrl: data['avatarUrl'],
      bio: data['bio'],
      workspaceIds: List<String>.from(data['workspaceIds'] ?? []),
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'email': email,
    'name': name,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'workspaceIds': workspaceIds,
    'notificationsEnabled': notificationsEnabled,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    String? bio,
    List<String>? workspaceIds,
    bool? notificationsEnabled,
  }) => UserModel(
    id: id,
    email: email,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
    workspaceIds: workspaceIds ?? this.workspaceIds,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, email, name, avatarUrl, bio, workspaceIds];
}
