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

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) return DateTime.parse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ChannelModel(
      id: (json['id'] ?? '').toString(),
      workspaceId: (json['workspaceId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      isAnnouncement: json['isAnnouncement'] == true,
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'isAnnouncement': isAnnouncement,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [id, workspaceId, name];
}
