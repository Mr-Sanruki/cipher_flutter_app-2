import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/app_config_provider.dart';

final groqServiceProvider = Provider<GroqService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final key = cfg.groqApiKey.isNotEmpty ? cfg.groqApiKey : AppConstants.effectiveGroqApiKey;
  return GroqService(apiKey: key);
});

class GroqMessage {
  final String role;
  final String content;
  const GroqMessage({required this.role, required this.content});
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class GroqService {
  late final Dio _dio;
  final String _apiKey;

  GroqService({required String apiKey}) : _apiKey = apiKey {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.groqBaseUrl,
      headers: {
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  Future<String> chat(List<GroqMessage> messages) async {
    if (_apiKey.isEmpty) {
      throw Exception('Missing GROQ_API_KEY. Set it in Settings > AI Assistant.');
    }
    final response = await _dio.post('/chat/completions', data: {
      'model': AppConstants.groqModel,
      'messages': messages.map((m) => m.toJson()).toList(),
      'max_tokens': 1024,
      'temperature': 0.7,
    });
    return response.data['choices'][0]['message']['content'] as String;
  }
}
