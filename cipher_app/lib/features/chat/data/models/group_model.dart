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

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) return DateTime.parse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return GroupModel(
      id: (json['id'] ?? '').toString(),
      workspaceId: (json['workspaceId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      iconUrl: json['iconUrl']?.toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      memberIds: (json['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'name': name,
    'iconUrl': iconUrl,
    'createdBy': createdBy,
    'memberIds': memberIds,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [id, workspaceId, name];
}
