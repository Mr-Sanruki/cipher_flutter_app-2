import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../auth/data/repositories/auth_repository.dart';

final groqServiceProvider = Provider<GroqService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return GroqService(baseUrl: cfg.backendBaseUrl, authRepo: ref.watch(authRepositoryProvider));
});

class GroqMessage {
  final String role;
  final String content;
  const GroqMessage({required this.role, required this.content});
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class GroqService {
  final Dio _dio;
  final AuthRepository _authRepo;

  GroqService({required String baseUrl, required AuthRepository authRepo})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        )),
        _authRepo = authRepo;

  Future<String> chat(List<GroqMessage> messages) async {
    final jwt = _authRepo.getSavedToken();
    if (jwt == null) throw Exception('UNAUTHORIZED');

    final response = await _dio.post(
      '/ai/chat',
      data: {'messages': messages.map((m) => m.toJson()).toList()},
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );

    final data = response.data;
    if (data is Map && data['content'] is String) {
      return data['content'] as String;
    }
    throw Exception('Invalid AI response');
  }
}
