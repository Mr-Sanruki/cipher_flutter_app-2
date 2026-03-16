import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  return ref.watch(authRepositoryProvider).getCurrentUser();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;
  AuthNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> sendOtp(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.sendOtp(email));
  }

  Future<void> signInWithLink(String email, String link) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final cred = await _repo.signInWithEmailLink(email, link);
      if (cred.user != null) await _repo.getOrCreateUser(cred.user!);
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.signOut());
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.deleteAccount());
  }
}
