import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/app_config_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return AuthRepository(baseUrl: cfg.backendBaseUrl);
});

class AuthRepository {
  final Dio _dio;

  AuthRepository({required String baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )) {
    debugPrint('[auth] baseUrl=${_dio.options.baseUrl}');
  }

  Future<String> getStreamUserToken() async {
    try {
      final res = await _dio.get(
        '/calls/token',
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['token'] is String && (data['token'] as String).isNotEmpty) {
        return data['token'] as String;
      }
      throw Exception('Invalid token response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Map<String, String> _headers() {
    final jwt = getSavedToken();
    if (jwt == null) throw Exception('UNAUTHORIZED');
    return {'Authorization': 'Bearer $jwt'};
  }

  String? getSavedToken() {
    final box = Hive.box(AppConstants.settingsBox);
    final t = box.get('auth_token');
    return t is String && t.isNotEmpty ? t : null;
  }

  String? getSavedBackendUserId() {
    final box = Hive.box(AppConstants.settingsBox);
    final v = box.get('backend_user_id');
    return v is String && v.isNotEmpty ? v : null;
  }

  Future<void> saveBackendUserId(String? id) async {
    final box = Hive.box(AppConstants.settingsBox);
    if (id == null || id.isEmpty) {
      await box.delete('backend_user_id');
    } else {
      await box.put('backend_user_id', id);
    }
  }

  Future<void> saveToken(String? token) async {
    final box = Hive.box(AppConstants.settingsBox);
    if (token == null || token.isEmpty) {
      await box.delete('auth_token');
    } else {
      await box.put('auth_token', token);
    }
  }

  Future<void> sendOtp(String email) async {
    try {
      final res = await _dio.post('/auth/request-otp', data: {'email': email});
      debugPrint('[auth] request-otp ok status=${res.statusCode} uri=${res.requestOptions.uri}');
    } on DioException catch (e) {
      debugPrint('[auth] request-otp error type=${e.type} message=${e.message} uri=${e.requestOptions.uri}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerWithPassword({
    required String email,
    required String name,
    required String password,
  }) async {
    late final Response res;
    try {
      res = await _dio.post('/auth/register', data: {'email': email, 'name': name, 'password': password});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }

    final data = res.data;
    if (data is! Map) throw Exception('Invalid response');
    final token = data['token'];
    if (token is! String || token.isEmpty) throw Exception('Missing token');
    await saveToken(token);

    final user = data['user'];
    if (user is Map && user['id'] != null) {
      await saveBackendUserId(user['id'].toString());
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    late final Response res;
    try {
      res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }

    final data = res.data;
    if (data is! Map) throw Exception('Invalid response');
    final token = data['token'];
    if (token is! String || token.isEmpty) throw Exception('Missing token');
    await saveToken(token);

    final user = data['user'];
    if (user is Map && user['id'] != null) {
      await saveBackendUserId(user['id'].toString());
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> verifyOtp({required String email, required String code}) async {
    late final Response res;
    try {
      res = await _dio.post('/auth/verify-otp', data: {'email': email, 'code': code});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      throw Exception(e.message ?? 'Network error');
    }

    final data = res.data;
    if (data is! Map) throw Exception('Invalid response');
    final token = data['token'];
    if (token is! String || token.isEmpty) throw Exception('Missing token');
    await saveToken(token);

    final user = data['user'];
    if (user is Map && user['id'] != null) {
      await saveBackendUserId(user['id'].toString());
    }

    return Map<String, dynamic>.from(data);
  }

  Future<UserModel?> getCurrentUser() async {
    final jwt = getSavedToken();
    if (jwt == null) return null;
    try {
      final res = await _dio.get(
        '/me',
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map) return UserModel.fromJson(Map<String, dynamic>.from(data));
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return [];

    try {
      final res = await _dio.post(
        '/users/bulk',
        data: {'ids': ids},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      final items = (data is Map) ? data['items'] : null;
      if (items is List) {
        final out = items
            .whereType<Map>()
            .map((m) => UserModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return out;
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<void> setPresence({required bool isOnline}) async {
    final jwt = getSavedToken();
    if (jwt == null) return;
    try {
      await _dio.post(
        '/me/presence',
        data: {'isOnline': isOnline},
        options: Options(headers: _headers()),
      );
    } on DioException catch (_) {}
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _dio.patch(
        '/me',
        data: {
          'name': user.name,
          'bio': user.bio,
          'avatarUrl': user.avatarUrl,
          'notificationsEnabled': user.notificationsEnabled,
        },
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<String> uploadAvatar(String filePath) async {
    final fileName = filePath.split('/').last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    try {
      final res = await _dio.post(
        '/uploads/avatar',
        data: form,
        options: Options(
          headers: {
            ..._headers(),
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      final data = res.data;
      if (data is Map && data['url'] != null) return data['url'].toString();
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<void> deleteAccount() async {
    final jwt = getSavedToken();
    if (jwt == null) return;
    try {
      await _dio.delete(
        '/me',
        options: Options(headers: _headers()),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    } finally {
      await saveToken(null);
      await saveBackendUserId(null);
    }
  }

  Future<void> signOut() async {
    await saveToken(null);
    await saveBackendUserId(null);
  }
}
