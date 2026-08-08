import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:drift/drift.dart' as drift;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/providers.dart';

class UsersView extends ConsumerStatefulWidget {
  const UsersView({super.key});

  @override
  ConsumerState<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends ConsumerState<UsersView> {
  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersStreamProvider);
    
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
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context),
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
                              subtitle: Text('اسم الدخول: ${user.username} | الدور: ${user.role == 'admin' ? 'مدير' : 'كاشير'}', style: const TextStyle(fontFamily: 'Cairo')),
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
                                  IconButton(
                                    icon: const Icon(LucideIcons.key, color: AppColors.warning),
                                    onPressed: () => _showPermissionsDialog(context, user),
                                    tooltip: 'الصلاحيات',
                                  ),
                                  IconButton(
                                    icon: Icon(user.isActive ? LucideIcons.userMinus : LucideIcons.userCheck, color: user.isActive ? AppColors.error : AppColors.success),
                                    onPressed: () => _toggleUserStatus(user),
                                    tooltip: user.isActive ? 'إيقاف المستخدم' : 'تفعيل المستخدم',
                                  ),
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
  
  void _showAddUserDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddUserDialog());
  }

  void _showPermissionsDialog(BuildContext context, User user) {
    showDialog(context: context, builder: (context) => UserPermissionsDialog(user: user));
  }

  Future<void> _toggleUserStatus(User user) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.users)..where((t) => t.id.equals(user.id)))
        .write(UsersCompanion(isActive: drift.Value(!user.isActive)));
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
                DropdownMenuItem(value: 'cashier', child: Text('كاشير', style: TextStyle(fontFamily: 'Cairo'))),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء إكمال البيانات')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      
      final bytes = utf8.encode(_passwordController.text);
      final digest = sha256.convert(bytes);
      final hashed = digest.toString();

      final userId = await db.into(db.users).insert(
        UsersCompanion.insert(
          fullName: _fullNameController.text,
          username: _usernameController.text,
          passwordHash: hashed,
          role: _role,
        )
      );

      final modules = ['products', 'pos', 'purchases', 'reports', 'settings'];
      for (final mod in modules) {
        await db.into(db.permissions).insert(
          PermissionsCompanion.insert(
            userId: userId,
            module: mod,
            canView: drift.Value(_role == 'admin' || mod == 'pos' || mod == 'products'),
            canCreate: drift.Value(_role == 'admin' || mod == 'pos'),
            canEdit: drift.Value(_role == 'admin'),
            canDelete: drift.Value(_role == 'admin'),
          )
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المستخدم بنجاح')));
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        setState(() => _isLoading = false);
      }
    }
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
    setState(() {
      _permissions = perms;
      _isLoading = false;
    });
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
    _loadPermissions();
  }

  String _moduleName(String mod) {
    switch(mod) {
      case 'products': return 'المنتجات والمخزون';
      case 'pos': return 'نقاط البيع (POS)';
      case 'purchases': return 'المشتريات والموردين';
      case 'reports': return 'التقارير المالية';
      case 'settings': return 'الإعدادات';
      default: return mod;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('صلاحيات: ${widget.user.fullName}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 600.w,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DataTable(
                  headingTextStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  columns: const [
                    DataColumn(label: Text('القسم')),
                    DataColumn(label: Text('عرض')),
                    DataColumn(label: Text('إضافة')),
                    DataColumn(label: Text('تعديل')),
                    DataColumn(label: Text('حذف (مرتجع)')),
                  ],
                  rows: _permissions.map((p) => DataRow(
                    cells: [
                      DataCell(Text(_moduleName(p.module), style: const TextStyle(fontFamily: 'Cairo'))),
                      DataCell(Checkbox(value: p.canView, onChanged: (v) => _updatePermission(p, view: v))),
                      DataCell(Checkbox(value: p.canCreate, onChanged: (v) => _updatePermission(p, create: v))),
                      DataCell(Checkbox(value: p.canEdit, onChanged: (v) => _updatePermission(p, edit: v))),
                      DataCell(Checkbox(value: p.canDelete, onChanged: (v) => _updatePermission(p, delete: v))),
                    ]
                  )).toList(),
                )
              ],
            ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo'))),
      ],
    );
  }
}
