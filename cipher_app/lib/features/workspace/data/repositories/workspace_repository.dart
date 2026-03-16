import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/workspace_model.dart';
import '../../../../core/constants/app_constants.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) => WorkspaceRepository());

class WorkspaceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<WorkspaceModel> createWorkspace({
    required String name,
    required String ownerId,
    String? description,
  }) async {
    final inviteCode = _uuid.v4().substring(0, 8).toUpperCase();
    final ref = _db.collection(AppConstants.workspacesCollection).doc();
    final workspace = WorkspaceModel(
      id: ref.id,
      name: name,
      description: description,
      ownerId: ownerId,
      memberIds: [ownerId],
      adminIds: [ownerId],
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
    );
    await ref.set(workspace.toFirestore());
    await _db.collection(AppConstants.usersCollection).doc(ownerId).update({
      'workspaceIds': FieldValue.arrayUnion([ref.id]),
    });
    return workspace;
  }

  Future<WorkspaceModel?> joinByInviteCode(String code, String userId) async {
    final query = await _db
        .collection(AppConstants.workspacesCollection)
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    await doc.reference.update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'workspaceIds': FieldValue.arrayUnion([doc.id]),
    });
    return WorkspaceModel.fromFirestore(doc);
  }

  Stream<List<WorkspaceModel>> getUserWorkspaces(String userId) {
    return _db
        .collection(AppConstants.workspacesCollection)
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((s) => s.docs.map(WorkspaceModel.fromFirestore).toList());
  }

  Future<WorkspaceModel?> getWorkspace(String id) async {
    final doc = await _db.collection(AppConstants.workspacesCollection).doc(id).get();
    if (!doc.exists) return null;
    return WorkspaceModel.fromFirestore(doc);
  }

  Future<void> updateWorkspace(WorkspaceModel workspace) async {
    await _db
        .collection(AppConstants.workspacesCollection)
        .doc(workspace.id)
        .update(workspace.toFirestore());
  }

  Future<void> leaveWorkspace(String workspaceId, String userId) async {
    await _db.collection(AppConstants.workspacesCollection).doc(workspaceId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
    });
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'workspaceIds': FieldValue.arrayRemove([workspaceId]),
    });
  }

  Future<void> makeAdmin(String workspaceId, String userId) async {
    await _db.collection(AppConstants.workspacesCollection).doc(workspaceId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
    });
  }
}
