import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';

class UsersManagementView extends ConsumerStatefulWidget {
  const UsersManagementView({super.key});

  @override
  ConsumerState<UsersManagementView> createState() => _UsersManagementViewState();
}

class _UsersManagementViewState extends ConsumerState<UsersManagementView> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'إدارة المستخدمين',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.h),
          child: Container(color: AppColors.border, height: 1.h),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: () => _showAddEditUserDialog(null),
              icon: Icon(LucideIcons.plus, color: Colors.white, size: 18),
              label: Text('إضافة مستخدم', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<User>>(
        stream: db.select(db.users).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final usersList = snapshot.data ?? [];
          
          if (usersList.isEmpty) {
            return Center(
              child: Text('لا يوجد مستخدمين مسجلين', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(24.w),
            itemCount: usersList.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final user = usersList[index];
              return Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
                      child: Icon(LucideIcons.user, color: AppColors.primary),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16.sp),
                          ),
                          Text(
                            '@${user.username} - ${user.role}',
                            style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: user.isActive ? AppColors.successLight : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        user.isActive ? 'نشط' : 'موقوف',
                        style: TextStyle(
                          color: user.isActive ? AppColors.success : AppColors.textSecondary,
                          fontFamily: 'Cairo',
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    IconButton(
                      icon: Icon(LucideIcons.edit2, color: AppColors.textSecondary, size: 20),
                      onPressed: () => _showAddEditUserDialog(user),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.trash2, color: AppColors.error, size: 20),
                      onPressed: () => _confirmDelete(user),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddEditUserDialog(User? user) {
    final isEditing = user != null;
    final fullNameCtrl = TextEditingController(text: user?.fullName ?? '');
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final passwordCtrl = TextEditingController();
    String role = user?.role ?? 'كاشير';
    bool isActive = user?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEditing ? 'تعديل مستخدم' : 'إضافة مستخدم جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400.w,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: fullNameCtrl,
                        decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: usernameCtrl,
                        decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: passwordCtrl,
                        decoration: InputDecoration(
                          labelText: isEditing ? 'كلمة المرور (اتركها فارغة لعدم التغيير)' : 'كلمة المرور',
                          border: const OutlineInputBorder()
                        ),
                        obscureText: true,
                        validator: (v) => (!isEditing && v!.isEmpty) ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'الصلاحية', border: OutlineInputBorder()),
                        items: ['مدير', 'كاشير', 'أمين مخزن'].map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(fontFamily: 'Cairo')))).toList(),
                        onChanged: (v) => role = v!,
                      ),
                      SizedBox(height: 12.h),
                      SwitchListTile(
                        title: Text('حساب نشط', style: TextStyle(fontFamily: 'Cairo')),
                        value: isActive,
                        onChanged: (v) {
                          isActive = v;
                          (ctx as Element).markNeedsBuild();
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final db = ref.read(databaseProvider);
                    if (isEditing) {
                      await db.update(db.users).replace(
                        user.copyWith(
                          fullName: fullNameCtrl.text,
                          username: usernameCtrl.text,
                          passwordHash: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : user.passwordHash,
                          role: role,
                          isActive: isActive,
                        ),
                      );
                    } else {
                      await db.into(db.users).insert(
                        UsersCompanion.insert(
                          fullName: fullNameCtrl.text,
                          username: usernameCtrl.text,
                          passwordHash: passwordCtrl.text,
                          role: role,
                          isActive: drift.Value(isActive),
                        ),
                      );
                    }
                    if (mounted) Navigator.pop(ctx);
                  }
                },
                child: Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
        content: Text('هل أنت متأكد من حذف المستخدم ${user.fullName}؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.delete(db.users).delete(user);
              if (mounted) Navigator.pop(ctx);
            },
            child: Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
