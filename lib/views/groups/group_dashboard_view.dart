import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group_model.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/group_viewmodel.dart';
import '../tasks/task_list_view.dart';
import 'create_group_sheet.dart';
import 'group_list_view.dart';
import '../tasks/create_task_sheet.dart';
import '../admin/manage_users_view.dart';

class GroupDashboardView extends StatelessWidget {
  const GroupDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final groupViewModel = context.watch<GroupViewModel>();

    final selectedGroupId = groupViewModel.selectedGroupId;
    final selectedGroup = groupViewModel.selectedGroup;
    final isAdmin = authViewModel.isAdmin;
    final user = authViewModel.currentUser;

    final isLeader = selectedGroup?.leaderId == user?.uid;
    final canCreateTask = isAdmin || isLeader;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _DashboardHeader(
                  displayName: (user?.displayName ?? '').trim().isEmpty
                      ? 'Halo'
                      : user!.displayName,
                  email: user?.email ?? '',
                  isAdmin: isAdmin,
                  onManageUsers: isAdmin ? () => _openManageUsers(context) : null,
                  onSignOut: authViewModel.signOut,
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _GroupSection(
                    selectedGroup: selectedGroup,
                    isAdmin: isAdmin,
                    onCreateGroup: () => _openCreateGroupSheet(context),
                    onManageGroup: selectedGroup != null
                        ? () => _showGroupManagementMenu(context, selectedGroup)
                        : null,
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Daftar Tugas',
                    trailing: canCreateTask
                        ? _AddButton(
                            label: 'Tambah',
                            onPressed: selectedGroupId == null
                                ? null
                                : () => _openCreateTaskSheet(context, selectedGroupId),
                          )
                        : null,
                  ),
                ),
              ),
            ];
          },
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: selectedGroupId == null
                ? _EmptyDashboardState(key: const ValueKey('empty'), isAdmin: isAdmin)
                : const TaskListView(key: ValueKey('tasks')),
          ),
        ),
      ),
      floatingActionButton: canCreateTask
          ? _QuickFAB(
              onPressed: () => _openQuickActions(
                context,
                selectedGroupId: selectedGroupId,
                isAdmin: isAdmin,
              ),
            )
          : null,
    );
  }

  Future<void> _openManageUsers(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageUsersView()),
    );
  }

  void _showGroupManagementMenu(BuildContext context, GroupModel group) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                group.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent),
              ),
              title: const Text('Edit Kelompok', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showEditGroupDialog(context, group);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
              ),
              title: const Text('Hapus Kelompok',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                _showDeleteGroupConfirm(context, group);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditGroupDialog(BuildContext context, GroupModel group) async {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Kelompok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Kelompok'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await context.read<GroupViewModel>().updateGroup(
                    groupId: group.id,
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteGroupConfirm(BuildContext context, GroupModel group) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelompok'),
        content: Text(
          'Yakin ingin menghapus kelompok "${group.name}"? Semua tugas di dalamnya akan ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              await context.read<GroupViewModel>().deleteGroup(group.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateGroupSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SafeArea(child: CreateGroupSheet()),
    );
  }

  Future<void> _openCreateTaskSheet(BuildContext context, String groupId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: CreateTaskSheet(groupId: groupId),
        ),
      ),
    );
  }

  Future<void> _openQuickActions(
    BuildContext context, {
    required String? selectedGroupId,
    required bool isAdmin,
  }) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdmin)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.group_add_outlined, size: 18, color: AppTheme.accent),
                  ),
                  title: const Text('Buat Kelompok', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _openCreateGroupSheet(context);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectedGroupId != null
                        ? const Color(0xFFE8F0FE)
                        : const Color(0xFFEEEFF8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_task_outlined,
                    size: 18,
                    color: selectedGroupId != null ? AppTheme.accent : AppTheme.muted,
                  ),
                ),
                title: Text(
                  'Buat Tugas',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selectedGroupId != null ? AppTheme.primary : AppTheme.muted,
                  ),
                ),
                subtitle: selectedGroupId == null
                    ? const Text('Pilih kelompok terlebih dahulu')
                    : null,
                enabled: selectedGroupId != null,
                onTap: selectedGroupId == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _openCreateTaskSheet(context, selectedGroupId);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.displayName,
    required this.email,
    required this.isAdmin,
    required this.onSignOut,
    this.onManageUsers,
  });

  final String displayName;
  final String email;
  final bool isAdmin;
  final VoidCallback onSignOut;
  final VoidCallback? onManageUsers;

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    displayName.trim().isNotEmpty
                        ? displayName.trim()[0].toUpperCase()
                        : 'T',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ... kode Avatar di atasnya ...
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            
              if (isAdmin) ...[
                _HeaderIconBtn(
                  icon: Icons.manage_accounts_outlined,
                  onPressed: onManageUsers,
                  tooltip: 'Kelola Pengguna',
                ),
              ],
              _HeaderIconBtn(
                icon: Icons.logout_rounded,
                onPressed: onSignOut,
                tooltip: 'Keluar',
              ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            _AdminBadge(),
          ],
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi 👋';
    if (hour < 15) return 'Selamat siang 👋';
    if (hour < 18) return 'Selamat sore 👋';
    return 'Selamat malam 👋';
  }
}

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: AppTheme.muted),
        ),
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: Color(0xFF6C63FF)),
          SizedBox(width: 4),
          Text(
            'Mode Admin',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C63FF),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Group section ─────────────────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.selectedGroup,
    required this.isAdmin,
    required this.onCreateGroup,
    required this.onManageGroup,
  });

  final GroupModel? selectedGroup;
  final bool isAdmin;
  final VoidCallback onCreateGroup;
  final VoidCallback? onManageGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Kelompok',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (isAdmin) ...[
                if (selectedGroup != null && onManageGroup != null)
                  _CompactButton(
                    icon: Icons.settings_outlined,
                    label: 'Kelola',
                    onPressed: onManageGroup,
                    accent: false,
                  ),
                const SizedBox(width: 8),
                _CompactButton(
                  icon: Icons.add_rounded,
                  label: 'Buat',
                  onPressed: onCreateGroup,
                  accent: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const GroupListView(padding: EdgeInsets.zero, height: 50),
          if (selectedGroup != null && selectedGroup!.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                selectedGroup!.description,
                key: ValueKey(selectedGroup!.id),
                style: const TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent ? AppTheme.accent : const Color(0xFFEEEFF8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent ? Colors.white : AppTheme.muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent ? Colors.white : AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color.fromARGB(255, 255, 255, 255),
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: onPressed != null ? AppTheme.accent : AppTheme.border,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: onPressed != null ? Colors.white : AppTheme.muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: onPressed != null ? Colors.white : AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _QuickFAB extends StatelessWidget {
  const _QuickFAB({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'quick-actions',
      onPressed: onPressed,
      child: const Icon(Icons.add_rounded),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.layers_outlined,
                  color: AppTheme.accent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih kelompok',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isAdmin
                    ? 'Buat kelompok baru atau pilih kelompok yang sudah ada.'
                    : 'Pilih kelompok di atas, lalu daftar tugas akan muncul di sini.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.muted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
