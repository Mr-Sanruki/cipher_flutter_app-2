import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/workspace_model.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final selectedWorkspaceProvider = StateProvider<WorkspaceModel?>((ref) => null);

final userWorkspacesProvider = StreamProvider<List<WorkspaceModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(workspaceRepositoryProvider).getUserWorkspaces(user.uid);
});

final workspaceNotifierProvider =
    StateNotifierProvider<WorkspaceNotifier, AsyncValue<void>>((ref) {
  return WorkspaceNotifier(ref.watch(workspaceRepositoryProvider), ref);
});

class WorkspaceNotifier extends StateNotifier<AsyncValue<void>> {
  final WorkspaceRepository _repo;
  final Ref _ref;
  WorkspaceNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<WorkspaceModel?> createWorkspace(String name, {String? description}) async {
    state = const AsyncValue.loading();
    WorkspaceModel? workspace;
    state = await AsyncValue.guard(() async {
      final userId = _ref.read(authStateProvider).value!.uid;
      workspace = await _repo.createWorkspace(
        name: name,
        ownerId: userId,
        description: description,
      );
      _ref.read(selectedWorkspaceProvider.notifier).state = workspace;
    });
    return workspace;
  }

  Future<WorkspaceModel?> joinWorkspace(String code) async {
    state = const AsyncValue.loading();
    WorkspaceModel? workspace;
    state = await AsyncValue.guard(() async {
      final userId = _ref.read(authStateProvider).value!.uid;
      workspace = await _repo.joinByInviteCode(code, userId);
      if (workspace != null) {
        _ref.read(selectedWorkspaceProvider.notifier).state = workspace;
      }
    });
    return workspace;
  }

  Future<void> leaveWorkspace(String workspaceId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final userId = _ref.read(authStateProvider).value!.uid;
      await _repo.leaveWorkspace(workspaceId, userId);
      _ref.read(selectedWorkspaceProvider.notifier).state = null;
    });
  }
}
