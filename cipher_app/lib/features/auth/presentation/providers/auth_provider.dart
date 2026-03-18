import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final authStateProvider = Provider<bool>((ref) {
  return ref.watch(authTokenProvider) != null;
});

final authTokenProvider = StateNotifierProvider<AuthTokenNotifier, String?>((ref) {
  return AuthTokenNotifier(ref.watch(authRepositoryProvider));
});

final backendUserIdProvider = StateNotifierProvider<BackendUserIdNotifier, String?>((ref) {
  return BackendUserIdNotifier(ref.watch(authRepositoryProvider));
});

class AuthTokenNotifier extends StateNotifier<String?> {
  final AuthRepository _repo;
  AuthTokenNotifier(this._repo) : super(_repo.getSavedToken());

  Future<void> refresh() async {
    state = _repo.getSavedToken();
  }

  Future<void> clear() async {
    await _repo.saveToken(null);
    state = null;
  }
}

class BackendUserIdNotifier extends StateNotifier<String?> {
  final AuthRepository _repo;
  BackendUserIdNotifier(this._repo) : super(_repo.getSavedBackendUserId());

  Future<void> refresh() async {
    state = _repo.getSavedBackendUserId();
  }

  Future<void> clear() async {
    await _repo.saveBackendUserId(null);
    state = null;
  }
}

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  return ref.watch(authRepositoryProvider).getCurrentUser();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref: ref, repo: ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;
  final Ref _ref;
  AuthNotifier({required Ref ref, required AuthRepository repo})
      : _ref = ref,
        _repo = repo,
        super(const AsyncValue.data(null));

  Future<void> sendOtp(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.sendOtp(email));
  }

  Future<void> verifyOtp({required String email, required String code}) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.verifyOtp(email: email, code: code);
      await _ref.read(authTokenProvider.notifier).refresh();
      await _ref.read(backendUserIdProvider.notifier).refresh();
    });
  }

  Future<void> registerWithPassword({required String email, required String name, required String password}) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.registerWithPassword(email: email, name: name, password: password);
      await _ref.read(authTokenProvider.notifier).refresh();
      await _ref.read(backendUserIdProvider.notifier).refresh();
    });
  }

  Future<void> loginWithPassword({required String email, required String password}) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.loginWithPassword(email: email, password: password);
      await _ref.read(authTokenProvider.notifier).refresh();
      await _ref.read(backendUserIdProvider.notifier).refresh();
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.signOut();
      await _ref.read(authTokenProvider.notifier).clear();
      await _ref.read(backendUserIdProvider.notifier).clear();
    });
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.deleteAccount());
  }
}
