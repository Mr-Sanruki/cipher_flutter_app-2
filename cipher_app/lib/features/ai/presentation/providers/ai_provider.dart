import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/groq_service.dart';

class AiMessage {
  final String content;
  final bool isUser;
  const AiMessage({required this.content, required this.isUser});
}

final aiMessagesProvider = StateNotifierProvider<AiMessagesNotifier, List<AiMessage>>((ref) {
  return AiMessagesNotifier(ref.watch(groqServiceProvider));
});

final aiLoadingProvider = StateProvider<bool>((ref) => false);

class AiMessagesNotifier extends StateNotifier<List<AiMessage>> {
  final GroqService _service;
  AiMessagesNotifier(this._service) : super([]);

  Future<void> sendMessage(String content, WidgetRef ref) async {
    state = [...state, AiMessage(content: content, isUser: true)];
    ref.read(aiLoadingProvider.notifier).state = true;
    try {
      final history = state.map((m) => GroqMessage(
        role: m.isUser ? 'user' : 'assistant',
        content: m.content,
      )).toList();
      final reply = await _service.chat(history);
      state = [...state, AiMessage(content: reply, isUser: false)];
    } catch (e) {
      state = [...state, AiMessage(content: 'Error: $e', isUser: false)];
    } finally {
      ref.read(aiLoadingProvider.notifier).state = false;
    }
  }

  void clearHistory() => state = [];
}
