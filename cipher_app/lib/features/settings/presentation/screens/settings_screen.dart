import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

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
                  backgroundColor: const Color(0xFF6C63FF),
                  child: Text(
                    user?.name[0].toUpperCase() ?? 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(user?.name ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text(user?.email ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/settings/profile'),
              ),
            ),
            const SizedBox(height: 24),

            // Sections
            _sectionTitle('Account'),
            _settingsTile(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Edit name, avatar, bio',
              onTap: () => context.push('/settings/profile'),
            ),
            _settingsTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Account',
              subtitle: 'Logout, delete account',
              onTap: () => context.push('/settings/account'),
            ),
            const SizedBox(height: 16),

            _sectionTitle('Workspace'),
            _settingsTile(
              icon: Icons.workspaces_outlined,
              title: 'Workspace Management',
              subtitle: 'Rename, invite code, members',
              onTap: () => context.push('/settings/workspace'),
            ),
            _settingsTile(
              icon: Icons.swap_horiz_outlined,
              title: 'Switch Workspace',
              subtitle: 'Go to workspace list',
              onTap: () => context.go('/workspace'),
            ),
            const SizedBox(height: 16),

            _sectionTitle('Support'),
            _settingsTile(
              icon: Icons.smart_toy_outlined,
              title: 'AI Assistant',
              subtitle: 'Chat with Groq AI',
              onTap: () => context.push('/ai'),
            ),
            const SizedBox(height: 8),

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

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
  );

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    ),
  );
}
