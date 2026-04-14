import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace_model.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../../auth/data/repositories/auth_repository.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return WorkspaceRepository(ref.watch(authRepositoryProvider), baseUrl: cfg.backendBaseUrl);
});

class WorkspaceRepository {
  final AuthRepository _authRepo;
  final Dio _dio;

  WorkspaceRepository(this._authRepo, {required String baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ));

  Map<String, String> _headers() {
    final token = _authRepo.getSavedToken();
    if (token == null) throw Exception('UNAUTHORIZED');
    return {'Authorization': 'Bearer $token'};
  }

  Future<WorkspaceModel> createWorkspace({
    required String name,
    String? description,
  }) async {
    try {
      final res = await _dio.post(
        '/workspaces',
        data: {'name': name, 'description': description},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['workspace'] is Map) {
        return WorkspaceModel.fromJson(Map<String, dynamic>.from(data['workspace']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<WorkspaceModel?> joinByInviteCode(String code) async {
    try {
      final res = await _dio.post(
        '/workspaces/join',
        data: {'code': code},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['workspace'] is Map) {
        return WorkspaceModel.fromJson(Map<String, dynamic>.from(data['workspace']));
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Stream<List<WorkspaceModel>> watchMyWorkspaces({Duration pollEvery = const Duration(seconds: 3)}) async* {
    while (true) {
      yield await listMyWorkspaces();
      await Future<void>.delayed(pollEvery);
    }
  }

  Future<List<WorkspaceModel>> listMyWorkspaces() async {
    try {
      final res = await _dio.get(
        '/workspaces',
        options: Options(headers: _headers()),
      );
      final data = res.data;
      final items = (data is Map ? data['items'] : null);
      if (items is List) {
        return items
            .whereType<Map>()
            .map((m) => WorkspaceModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<void> leaveWorkspace(String workspaceId) async {
    try {
      await _dio.post(
        '/workspaces/$workspaceId/leave',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<WorkspaceModel> updateWorkspace(WorkspaceModel workspace) async {
    try {
      final res = await _dio.put(
        '/workspaces/${workspace.id}',
        data: {
          'name': workspace.name,
          'description': workspace.description,
          'iconUrl': workspace.iconUrl,
        },
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['workspace'] is Map) {
        return WorkspaceModel.fromJson(Map<String, dynamic>.from(data['workspace']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<WorkspaceModel> setMemberRole({
    required String workspaceId,
    required String memberId,
    required String role,
  }) async {
    try {
      final res = await _dio.post(
        '/workspaces/$workspaceId/roles',
        data: {'memberId': memberId, 'role': role},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['workspace'] is Map) {
        return WorkspaceModel.fromJson(Map<String, dynamic>.from(data['workspace']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<void> sendWorkspaceEmail({
    required String workspaceId,
    required String toUserId,
    required String subject,
    required String message,
  }) async {
    try {
      await _dio.post(
        '/email/workspaces/$workspaceId/send',
        data: {
          'toUserId': toUserId,
          'subject': subject,
          'message': message,
        },
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }
}
