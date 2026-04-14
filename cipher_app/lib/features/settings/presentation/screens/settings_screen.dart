import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Card
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Text(
                    user?.name[0].toUpperCase() ?? 'U',
                    style: TextStyle(color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(user?.name ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text(
                  user?.email ?? '',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                ),
                trailing: Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.5)),
                onTap: () => context.push('/settings/profile'),
              ),
            ),
            const SizedBox(height: 24),

            // Sections
            _sectionTitle(context, 'Account'),
            _settingsCard(
              context,
              children: [
                _settingsTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Profile',
                  subtitle: 'Edit name, avatar, bio',
                  onTap: () => context.push('/settings/profile'),
                ),
                _divider(context),
                _settingsTile(
                  context,
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account',
                  subtitle: 'Logout, delete account',
                  onTap: () => context.push('/settings/account'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionTitle(context, 'Workspace'),
            _settingsCard(
              context,
              children: [
                _settingsTile(
                  context,
                  icon: Icons.workspaces_outlined,
                  title: 'Workspace Management',
                  subtitle: 'Rename, invite code, members',
                  onTap: () => context.push('/settings/workspace'),
                ),
                _divider(context),
                _settingsTile(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: 'Send email to workspace members',
                  onTap: () => context.push('/settings/email'),
                ),
                _divider(context),
                _settingsTile(
                  context,
                  icon: Icons.swap_horiz_outlined,
                  title: 'Switch Workspace',
                  subtitle: 'Go to workspace list',
                  onTap: () => context.go('/workspace'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionTitle(context, 'Support'),
            _settingsCard(
              context,
              children: [
                _settingsTile(
                  context,
                  icon: Icons.smart_toy_outlined,
                  title: 'AI Assistant',
                  subtitle: 'Chat with Groq AI',
                  onTap: () => context.push('/ai'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go('/auth/login');
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.55),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _settingsCard(BuildContext context, {required List<Widget> children}) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(height: 1, thickness: 1, color: cs.outline.withValues(alpha: 0.35));
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65), fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
      onTap: onTap,
    );
  }
}
