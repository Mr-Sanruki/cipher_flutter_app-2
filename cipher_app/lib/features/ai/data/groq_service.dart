import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';

final groqServiceProvider = Provider<GroqService>((ref) => GroqService());

class GroqMessage {
  final String role;
  final String content;
  const GroqMessage({required this.role, required this.content});
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class GroqService {
  late final Dio _dio;

  GroqService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.groqBaseUrl,
      headers: {
        if (AppConstants.groqApiKey.isNotEmpty) 'Authorization': 'Bearer ${AppConstants.groqApiKey}',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  Future<String> chat(List<GroqMessage> messages) async {
    if (AppConstants.groqApiKey.isEmpty) {
      throw Exception('Missing GROQ_API_KEY. Run with --dart-define=GROQ_API_KEY=...');
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
