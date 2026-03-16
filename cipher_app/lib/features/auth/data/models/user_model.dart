import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final List<String> workspaceIds;
  final bool notificationsEnabled;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.workspaceIds = const [],
    this.notificationsEnabled = true,
    this.isOnline = false,
    this.lastSeenAt,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    return UserModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      bio: json['bio']?.toString(),
      workspaceIds: (json['workspaceIds'] is List)
          ? List<String>.from((json['workspaceIds'] as List).map((e) => e.toString()))
          : const [],
      notificationsEnabled: json['notificationsEnabled'] is bool ? json['notificationsEnabled'] as bool : true,
      isOnline: json['isOnline'] is bool ? json['isOnline'] as bool : false,
      lastSeenAt: dt(json['lastSeenAt']),
      createdAt: dt(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'workspaceIds': workspaceIds,
        'notificationsEnabled': notificationsEnabled,
        'isOnline': isOnline,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    String? bio,
    List<String>? workspaceIds,
    bool? notificationsEnabled,
    bool? isOnline,
    DateTime? lastSeenAt,
  }) => UserModel(
    id: id,
    email: email,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
    workspaceIds: workspaceIds ?? this.workspaceIds,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    isOnline: isOnline ?? this.isOnline,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, email, name, avatarUrl, bio, workspaceIds, notificationsEnabled, isOnline, lastSeenAt];
}
