import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/auth/auth_service.dart';

class UsersView extends ConsumerStatefulWidget {
  const UsersView({super.key});

  @override
  ConsumerState<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends ConsumerState<UsersView> {
  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersStreamProvider);
    final canManage = can(ref, 'users', 'edit');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المستخدمين والصلاحيات',
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                if (canManage)
                  ElevatedButton.icon(
                    onPressed: () => showDialog(context: context, builder: (context) => const AddUserDialog()),
                    icon: const Icon(LucideIcons.userPlus),
                    label: const Text('إضافة مستخدم جديد', style: TextStyle(fontFamily: 'Cairo')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 24.h),

            Expanded(
              child: usersAsync.when(
                data: (users) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: users.isEmpty
                      ? const Center(child: Text('لا يوجد مستخدمين', style: TextStyle(fontFamily: 'Cairo')))
                      : ListView.separated(
                          itemCount: users.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: user.role == 'admin' ? AppColors.primaryLight : AppColors.successLight,
                                child: Icon(
                                  user.role == 'admin' ? LucideIcons.shield : LucideIcons.user,
                                  color: user.role == 'admin' ? AppColors.primary : AppColors.success,
                                ),
                              ),
                              title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              subtitle: Text('اسم الدخول: ${user.username} | الدور: ${_roleLabel(user.role)}', style: const TextStyle(fontFamily: 'Cairo')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (user.isActive)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(4.r)),
                                      child: const Text('نشط', style: TextStyle(color: AppColors.success, fontSize: 12, fontFamily: 'Cairo')),
                                    )
                                  else
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(4.r)),
                                      child: const Text('موقوف', style: TextStyle(color: AppColors.error, fontSize: 12, fontFamily: 'Cairo')),
                                    ),
                                  SizedBox(width: 8.w),
                                  if (canManage) ...[
                                    IconButton(
                                      icon: const Icon(LucideIcons.pencil, color: AppColors.info),
                                      onPressed: () => showDialog(context: context, builder: (context) => EditUserDialog(user: user)),
                                      tooltip: 'تعديل',
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.key, color: AppColors.warning),
                                      onPressed: () => _showResetPasswordDialog(user),
                                      tooltip: 'تغيير كلمة المرور',
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.shieldCheck, color: AppColors.primary),
                                      onPressed: () => showDialog(context: context, builder: (context) => UserPermissionsDialog(user: user)),
                                      tooltip: 'الصلاحيات',
                                    ),
                                    IconButton(
                                      icon: Icon(user.isActive ? LucideIcons.userMinus : LucideIcons.userCheck, color: user.isActive ? AppColors.error : AppColors.success),
                                      onPressed: () => _toggleUserStatus(user),
                                      tooltip: user.isActive ? 'إيقاف المستخدم' : 'تفعيل المستخدم',
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'accountant':
        return 'محاسب';
      case 'cashier':
        return 'كاشير';
      case 'storekeeper':
        return 'أمين مخزن';
      default:
        return role;
    }
  }

  Future<void> _toggleUserStatus(User user) async {
    final db = ref.read(databaseProvider);
    final uid = ref.read(currentUserIdProvider) ?? 1;
    await (db.update(db.users)..where((t) => t.id.equals(user.id)))
        .write(UsersCompanion(isActive: drift.Value(!user.isActive)));
    await DbHelpers.logAudit(
      db,
      userId: uid,
      action: 'UPDATE',
      targetTable: 'users',
      recordId: user.id,
      details: user.isActive ? 'إيقاف المستخدم ${user.username}' : 'تفعيل المستخدم ${user.username}',
    );
  }

  void _showResetPasswordDialog(User user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تغيير كلمة مرور: ${user.fullName}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (controller.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور يجب ألا تقل عن 6 أحرف', style: TextStyle(fontFamily: 'Cairo'))));
                  return;
                }
                final db = ref.read(databaseProvider);
                final uid = ref.read(currentUserIdProvider) ?? 1;
                await (db.update(db.users)..where((t) => t.id.equals(user.id)))
                    .write(UsersCompanion(passwordHash: drift.Value(hashPassword(controller.text))));
                await DbHelpers.logAudit(db, userId: uid, action: 'UPDATE', targetTable: 'users', recordId: user.id, details: 'تغيير كلمة مرور ${user.username}');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}

class AddUserDialog extends ConsumerStatefulWidget {
  const AddUserDialog({super.key});

  @override
  ConsumerState<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<AddUserDialog> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'cashier';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مستخدم جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'الاسم بالكامل', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'اسم الدخول', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('مدير', style: TextStyle(fontFamily: 'Cairo'))),
                DropdownMenuItem(value: 'accountant', child: Text('محاسب', style: TextStyle(fontFamily: 'Cairo'))),
                DropdownMenuItem(value: 'cashier', child: Text('كاشير', style: TextStyle(fontFamily: 'Cairo'))),
                DropdownMenuItem(value: 'storekeeper', child: Text('أمين مخزن', style: TextStyle(fontFamily: 'Cairo'))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _role = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _isLoading ? null : _saveUser,
          child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('حفظ', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _saveUser() async {
    if (_fullNameController.text.isEmpty || _usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء إكمال البيانات', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور يجب ألا تقل عن 6 أحرف', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final actorId = ref.read(currentUserIdProvider) ?? 1;

      final userId = await db.into(db.users).insert(
        UsersCompanion.insert(
          fullName: _fullNameController.text,
          username: _usernameController.text.trim(),
          passwordHash: hashPassword(_passwordController.text),
          role: _role,
        )
      );

      // Create a permission row for every module based on the role defaults.
      final rolePerms = defaultPermissionsForRole(_role);
      for (final mod in appModules) {
        final ops = rolePerms[mod] ?? const [];
        await db.into(db.permissions).insert(
          PermissionsCompanion.insert(
            userId: userId,
            module: mod,
            canView: drift.Value(ops.contains('view')),
            canCreate: drift.Value(ops.contains('create')),
            canEdit: drift.Value(ops.contains('edit')),
            canDelete: drift.Value(ops.contains('delete')),
          )
        );
      }

      await DbHelpers.logAudit(db, userId: actorId, action: 'CREATE', targetTable: 'users', recordId: userId, details: 'إضافة مستخدم ${_usernameController.text} بدور $_role');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المستخدم بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }
}

class EditUserDialog extends ConsumerStatefulWidget {
  final User user;
  const EditUserDialog({super.key, required this.user});

  @override
  ConsumerState<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<EditUserDialog> {
  late final TextEditingController _fullNameController = TextEditingController(text: widget.user.fullName);
  late final TextEditingController _usernameController = TextEditingController(text: widget.user.username);
  late String _role = widget.user.role;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تعديل: ${widget.user.fullName}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'الاسم بالكامل', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'اسم الدخول', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('مدير', style: TextStyle(fontFamily: 'Cairo'))),
                DropdownMenuItem(value: 'accountant', child: Text('محاسب', style: TextStyle(fontFamily: 'Cairo'))),
                DropdownMenuItem(value: 'cashier', child: Text('كاشير', style: TextStyle(fontFamily: 'Cairo'))),
                DropdownMenuItem(value: 'storekeeper', child: Text('أمين مخزن', style: TextStyle(fontFamily: 'Cairo'))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _role = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: () async {
            if (_fullNameController.text.isEmpty || _usernameController.text.isEmpty) return;
            final db = ref.read(databaseProvider);
            final actorId = ref.read(currentUserIdProvider) ?? 1;
            await (db.update(db.users)..where((t) => t.id.equals(widget.user.id))).write(
              UsersCompanion(
                fullName: drift.Value(_fullNameController.text),
                username: drift.Value(_usernameController.text.trim()),
                role: drift.Value(_role),
              ),
            );
            // Changing the role resets permissions to that role's defaults.
            if (_role != widget.user.role) {
              await (db.delete(db.permissions)..where((t) => t.userId.equals(widget.user.id))).go();
              final rolePerms = defaultPermissionsForRole(_role);
              for (final mod in appModules) {
                final ops = rolePerms[mod] ?? const [];
                await db.into(db.permissions).insert(
                  PermissionsCompanion.insert(
                    userId: widget.user.id,
                    module: mod,
                    canView: drift.Value(ops.contains('view')),
                    canCreate: drift.Value(ops.contains('create')),
                    canEdit: drift.Value(ops.contains('edit')),
                    canDelete: drift.Value(ops.contains('delete')),
                  )
                );
              }
              await DbHelpers.logAudit(db, userId: actorId, action: 'UPDATE', targetTable: 'permissions', recordId: widget.user.id, details: 'إعادة تعيين صلاحيات ${widget.user.username} حسب الدور الجديد $_role');
            }
            await DbHelpers.logAudit(db, userId: actorId, action: 'UPDATE', targetTable: 'users', recordId: widget.user.id, details: 'تعديل بيانات ${_usernameController.text}');
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

class UserPermissionsDialog extends ConsumerStatefulWidget {
  final User user;
  const UserPermissionsDialog({super.key, required this.user});

  @override
  ConsumerState<UserPermissionsDialog> createState() => _UserPermissionsDialogState();
}

class _UserPermissionsDialogState extends ConsumerState<UserPermissionsDialog> {
  bool _isLoading = true;
  List<Permission> _permissions = [];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final db = ref.read(databaseProvider);
    final perms = await (db.select(db.permissions)..where((t) => t.userId.equals(widget.user.id))).get();

    // Ensure a row exists for every module so nothing is unreachable to edit.
    // Missing rows default to the user's role permissions, not open access.
    final existing = perms.map((p) => p.module).toSet();
    final rolePerms = defaultPermissionsForRole(widget.user.role);
    for (final mod in appModules) {
      if (!existing.contains(mod)) {
        final ops = rolePerms[mod] ?? const [];
        await db.into(db.permissions).insert(
          PermissionsCompanion.insert(
            userId: widget.user.id,
            module: mod,
            canView: drift.Value(ops.contains('view')),
            canCreate: drift.Value(ops.contains('create')),
            canEdit: drift.Value(ops.contains('edit')),
            canDelete: drift.Value(ops.contains('delete')),
          ),
        );
      }
    }

    final all = await (db.select(db.permissions)..where((t) => t.userId.equals(widget.user.id))).get();
    all.sort((a, b) => a.module.compareTo(b.module));
    if (mounted) {
      setState(() {
        _permissions = all;
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePermission(Permission p, {bool? view, bool? create, bool? edit, bool? delete}) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.permissions)..where((t) => t.id.equals(p.id))).write(
      PermissionsCompanion(
        canView: view != null ? drift.Value(view) : const drift.Value.absent(),
        canCreate: create != null ? drift.Value(create) : const drift.Value.absent(),
        canEdit: edit != null ? drift.Value(edit) : const drift.Value.absent(),
        canDelete: delete != null ? drift.Value(delete) : const drift.Value.absent(),
      )
    );
    await _loadPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('صلاحيات: ${widget.user.fullName}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 700.w,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: DataTable(
                headingTextStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                columns: const [
                  DataColumn(label: Text('القسم')),
                  DataColumn(label: Text('عرض')),
                  DataColumn(label: Text('إضافة')),
                  DataColumn(label: Text('تعديل')),
                  DataColumn(label: Text('حذف')),
                ],
                rows: _permissions.map((p) => DataRow(
                  cells: [
                    DataCell(Text(moduleLabels[p.module] ?? p.module, style: const TextStyle(fontFamily: 'Cairo'))),
                    DataCell(Checkbox(value: p.canView, onChanged: (v) => _updatePermission(p, view: v))),
                    DataCell(Checkbox(value: p.canCreate, onChanged: (v) => _updatePermission(p, create: v))),
                    DataCell(Checkbox(value: p.canEdit, onChanged: (v) => _updatePermission(p, edit: v))),
                    DataCell(Checkbox(value: p.canDelete, onChanged: (v) => _updatePermission(p, delete: v))),
                  ]
                )).toList(),
              ),
            ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo'))),
      ],
    );
  }
}
