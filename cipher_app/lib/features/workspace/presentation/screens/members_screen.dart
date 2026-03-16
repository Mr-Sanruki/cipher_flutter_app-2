import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/workspace_repository.dart';
import '../providers/workspace_provider.dart';

final workspaceMembersProvider = FutureProvider<List<UserModel>>((ref) async {
  final ws = ref.watch(selectedWorkspaceProvider);
  if (ws == null) return [];
  return ref.watch(authRepositoryProvider).getUsersByIds(ws.memberIds);
});

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(selectedWorkspaceProvider);
    final currentUserId = ref.watch(backendUserIdProvider) ?? '';

    if (ws == null) {
      return const Scaffold(
        body: Center(child: Text('No workspace selected')),
      );
    }

    final canManage = ws.canManageRoles(currentUserId);
    final membersAsync = ref.watch(workspaceMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('No members found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = members[i];
              final role = ws.roleFor(m.id);
              final isOwner = m.id == ws.ownerId;
              final canEditThis = canManage && !isOwner && m.id != currentUserId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6C63FF).withAlpha(38),
                  child: Text(
                    m.name.isNotEmpty ? m.name[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(m.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  m.isOnline
                      ? 'Online'
                      : (m.lastSeenAt != null ? 'Last seen ${timeago.format(m.lastSeenAt!)}' : m.email),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: canEditThis
                    ? TextButton(
                        onPressed: () => _showRolePicker(context, ref, memberId: m.id, currentRole: role),
                        child: Text(_labelForRole(role)),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _OnlineDot(isOnline: m.isOnline),
                          const SizedBox(width: 10),
                          _RoleChip(role: role),
                        ],
                      ),
                onTap: canEditThis
                    ? () => _showRolePicker(context, ref, memberId: m.id, currentRole: role)
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showRolePicker(
    BuildContext context,
    WidgetRef ref, {
    required String memberId,
    required String currentRole,
  }) async {
    final ws = ref.read(selectedWorkspaceProvider);
    if (ws == null) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Member'),
                trailing: currentRole == 'member' ? const Icon(Icons.check) : null,
                onTap: () async {
                  final updated = await ref.read(workspaceRepositoryProvider).setMemberRole(
                        workspaceId: ws.id,
                        memberId: memberId,
                        role: 'member',
                      );
                  ref.read(selectedWorkspaceProvider.notifier).setWorkspace(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('Admin'),
                trailing: currentRole == 'admin' ? const Icon(Icons.check) : null,
                onTap: () async {
                  final updated = await ref.read(workspaceRepositoryProvider).setMemberRole(
                        workspaceId: ws.id,
                        memberId: memberId,
                        role: 'admin',
                      );
                  ref.read(selectedWorkspaceProvider.notifier).setWorkspace(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsForRole(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _labelForRole(role),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _labelForRole(String role) {
  switch (role) {
    case 'owner':
      return 'Owner';
    case 'admin':
      return 'Admin';
    default:
      return 'Member';
  }
}

(Color, Color) _colorsForRole(String role) {
  switch (role) {
    case 'owner':
      return (Colors.amber.shade100, Colors.amber.shade900);
    case 'admin':
      return (Colors.blue.shade100, Colors.blue.shade800);
    default:
      return (Colors.grey.shade200, Colors.grey.shade800);
  }
}

class _OnlineDot extends StatelessWidget {
  final bool isOnline;

  const _OnlineDot({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.grey.shade400,
      ),
    );
  }
}
