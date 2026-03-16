import 'package:equatable/equatable.dart';

class WorkspaceModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String ownerId;
  final List<String> memberIds;
  final List<String> adminIds;
  final Map<String, String> memberRoles;
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
    this.memberRoles = const {},
    required this.inviteCode,
    required this.createdAt,
  });

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) return DateTime.parse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.now();
    }

    return WorkspaceModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      iconUrl: json['iconUrl']?.toString(),
      ownerId: (json['ownerId'] ?? '').toString(),
      memberIds: (json['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      adminIds: (json['adminIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      memberRoles: (json['memberRoles'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? 'member'),
          ) ??
          const {},
      inviteCode: (json['inviteCode'] ?? '').toString(),
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'iconUrl': iconUrl,
    'ownerId': ownerId,
    'memberIds': memberIds,
    'adminIds': adminIds,
    'memberRoles': memberRoles,
    'inviteCode': inviteCode,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  bool isAdmin(String userId) => adminIds.contains(userId) || ownerId == userId;

  String roleFor(String userId) {
    if (userId == ownerId) return 'owner';
    final role = memberRoles[userId];
    if (role != null) return role;
    if (adminIds.contains(userId)) return 'admin';
    return 'member';
  }

  bool canManageRoles(String userId) => isAdmin(userId);

  WorkspaceModel copyWith({
    String? name,
    String? description,
    String? iconUrl,
    List<String>? memberIds,
    List<String>? adminIds,
    Map<String, String>? memberRoles,
  }) => WorkspaceModel(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    iconUrl: iconUrl ?? this.iconUrl,
    ownerId: ownerId,
    memberIds: memberIds ?? this.memberIds,
    adminIds: adminIds ?? this.adminIds,
    memberRoles: memberRoles ?? this.memberRoles,
    inviteCode: inviteCode,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, name, ownerId, inviteCode, memberIds, adminIds, memberRoles];
}
