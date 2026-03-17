import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

class AppConfigState {
  final String backendBaseUrl;
  final String groqApiKey;

  const AppConfigState({
    required this.backendBaseUrl,
    required this.groqApiKey,
  });

  AppConfigState copyWith({
    String? backendBaseUrl,
    String? groqApiKey,
  }) =>
      AppConfigState(
        backendBaseUrl: backendBaseUrl ?? this.backendBaseUrl,
        groqApiKey: groqApiKey ?? this.groqApiKey,
      );
}

const _backendBaseUrlKey = 'backend_base_url_override';
const _groqApiKeyKey = 'groq_api_key_override';

final appConfigProvider = StateNotifierProvider<AppConfigNotifier, AppConfigState>((ref) {
  return AppConfigNotifier();
});

class AppConfigNotifier extends StateNotifier<AppConfigState> {
  late final Box _box;

  AppConfigNotifier()
      : super(
          AppConfigState(
            backendBaseUrl: AppConstants.backendBaseUrl,
            groqApiKey: AppConstants.effectiveGroqApiKey,
          ),
        ) {
    _box = Hive.box(AppConstants.settingsBox);

    final storedBackend = _box.get(_backendBaseUrlKey);
    final storedGroq = _box.get(_groqApiKeyKey);

    state = state.copyWith(
      backendBaseUrl: (storedBackend is String && storedBackend.trim().isNotEmpty)
          ? storedBackend.trim()
          : AppConstants.backendBaseUrl,
      groqApiKey: (storedGroq is String) ? storedGroq.trim() : '',
    );
  }

  Future<void> setBackendBaseUrl(String url) async {
    final next = url.trim();
    if (next.isEmpty) return;
    await _box.put(_backendBaseUrlKey, next);
    state = state.copyWith(backendBaseUrl: next);
  }

  Future<void> clearBackendBaseUrl() async {
    await _box.delete(_backendBaseUrlKey);
    state = state.copyWith(backendBaseUrl: AppConstants.backendBaseUrl);
  }

  Future<void> setGroqApiKey(String key) async {
    final next = key.trim();
    await _box.put(_groqApiKeyKey, next);
    state = state.copyWith(groqApiKey: next);
  }

  Future<void> clearGroqApiKey() async {
    await _box.delete(_groqApiKeyKey);
    state = state.copyWith(groqApiKey: '');
  }
}
