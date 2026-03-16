import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/workspace_model.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

const _selectedWorkspaceIdKey = 'selected_workspace_id';

final selectedWorkspaceProvider = StateNotifierProvider<SelectedWorkspaceNotifier, WorkspaceModel?>((ref) {
  return SelectedWorkspaceNotifier(ref);
});

class SelectedWorkspaceNotifier extends StateNotifier<WorkspaceModel?> {
  final Ref _ref;
  late final Box _box;

  SelectedWorkspaceNotifier(this._ref) : super(null) {
    _box = Hive.box(AppConstants.settingsBox);

    _ref.listen<AsyncValue<List<WorkspaceModel>>>(userWorkspacesProvider, (prev, next) {
      next.whenData((workspaces) {
        if (workspaces.isEmpty) {
          clear();
          return;
        }

        final storedId = _box.get(_selectedWorkspaceIdKey) as String?;
        if (storedId != null) {
          final stored = workspaces.where((w) => w.id == storedId).cast<WorkspaceModel?>().firstWhere(
                (w) => w != null,
                orElse: () => null,
              );
          if (stored != null) {
            if (state?.id != stored.id) state = stored;
            return;
          }
        }

        if (state == null || !workspaces.any((w) => w.id == state!.id)) {
          setWorkspace(workspaces.first);
        }
      });
    });

    _ref.listen(authStateProvider, (prev, next) {
      if (next == false) {
        clear();
      }
    });
  }

  void setWorkspace(WorkspaceModel workspace) {
    state = workspace;
    _box.put(_selectedWorkspaceIdKey, workspace.id);
  }

  void clear() {
    state = null;
    _box.delete(_selectedWorkspaceIdKey);
  }
}

final userWorkspacesProvider = StreamProvider<List<WorkspaceModel>>((ref) {
  final token = ref.watch(authTokenProvider);
  if (token == null) return const Stream.empty();
  return ref.watch(workspaceRepositoryProvider).watchMyWorkspaces();
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
      workspace = await _repo.createWorkspace(
        name: name,
        description: description,
      );
      if (workspace != null) {
        _ref.read(selectedWorkspaceProvider.notifier).setWorkspace(workspace!);
      }
    });
    return workspace;
  }

  Future<WorkspaceModel?> joinWorkspace(String code) async {
    state = const AsyncValue.loading();
    WorkspaceModel? workspace;
    state = await AsyncValue.guard(() async {
      workspace = await _repo.joinByInviteCode(code);
      if (workspace != null) {
        _ref.read(selectedWorkspaceProvider.notifier).setWorkspace(workspace!);
      }
    });
    return workspace;
  }

  Future<void> leaveWorkspace(String workspaceId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.leaveWorkspace(workspaceId);
      _ref.read(selectedWorkspaceProvider.notifier).clear();
    });
  }
}
