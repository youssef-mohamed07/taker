import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/db_helpers.dart';
import 'users_management_view.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإعدادات',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
            SizedBox(height: 24.h),
            _buildSettingCard(
              'المظهر',
              LucideIcons.palette,
              subtitle: isDark ? 'الوضع الداكن' : 'الوضع الفاتح',
              trailing: Switch(
                value: isDark,
                onChanged: (v) =>
                    ref.read(themeModeProvider.notifier).state = v,
              ),
            ),
            SizedBox(height: 12.h),
            _buildSettingCard(
              'المستخدمون',
              LucideIcons.userCog,
              subtitle: 'إدارة الحسابات والصلاحيات',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersManagementView()),
                );
              },
            ),
            SizedBox(height: 12.h),
            _buildSettingCard(
              'الطابعة',
              LucideIcons.printer,
              subtitle: 'إعدادات الطابعة الحرارية',
              onTap: () => _showPrinterSettingsDialog(context),
            ),
            SizedBox(height: 12.h),
            _buildSettingCard(
              'النسخ الاحتياطي',
              LucideIcons.hardDrive,
              subtitle: 'Backup & Restore',
              onTap: () => _showBackupRestoreDialog(context),
            ),
            SizedBox(height: 12.h),
            _buildSettingCard(
              'تصفير وإعادة ضبط البيانات',
              LucideIcons.trash2,
              subtitle: 'مسح كافة البيانات الوهمية والتجريبية لتسليم التطبيق',
              iconColor: Colors.red,
              onTap: () => _showResetDatabaseDialog(context, db),
            ),
            SizedBox(height: 12.h),
            _buildSettingCard(
              'حول البرنامج',
              LucideIcons.info,
              subtitle: 'الإصدار 1.0.0',
              onTap: () => _showAboutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDatabaseDialog(BuildContext context, db) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.red),
              SizedBox(width: 8.w),
              Text('تصفير قاعدة البيانات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في تصفير كافة البيانات؟\nسيتم مسح المنتجات، الفواتير، المبيعات، المشتريات، الشيفتات والحركات المالية نهائياً لتسليم النطام بحالة نظيفة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await DbHelpers.clearAllData(db);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تصفير كافة بيانات النظام بنجاح! جاهز للتسليم للعميل.', style: TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text('تأكيد التصفير', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrinterSettingsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String printerName = prefs.getString('printer_name') ?? 'طابعة وهمية (Mock)';
    String paperSize = prefs.getString('paper_size') ?? '80mm';

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(LucideIcons.printer, color: AppColors.primary),
                  SizedBox(width: 8.w),
                  Text('إعدادات الطابعة الحرارية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 400.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: printerName,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطابعة',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => printerName = v,
                    ),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<String>(
                      value: paperSize,
                      decoration: const InputDecoration(
                        labelText: 'حجم الورق',
                        border: OutlineInputBorder(),
                      ),
                      items: ['80mm', '58mm']
                          .map((size) => DropdownMenuItem(value: size, child: Text(size, style: TextStyle(fontFamily: 'Cairo'))))
                          .toList(),
                      onChanged: (v) => setDialogState(() => paperSize = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    await prefs.setString('printer_name', printerName);
                    await prefs.setString('paper_size', paperSize);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ إعدادات الطابعة بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: Text('حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showBackupRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.hardDrive, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text('النسخ الاحتياطي والاستعادة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'يمكنك أخذ نسخة احتياطية من قاعدة البيانات الحالية أو استعادة نسخة سابقة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton.icon(
              icon: Icon(LucideIcons.upload, size: 16, color: Colors.white),
              label: Text('استعادة نسخة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: () async {
                Navigator.pop(ctx);
                await _performRestore(context);
              },
            ),
            ElevatedButton.icon(
              icon: Icon(LucideIcons.download, size: 16, color: Colors.white),
              label: Text('أخذ نسخة احتياطية', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () async {
                Navigator.pop(ctx);
                await _performBackup(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performBackup(BuildContext context) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));
      
      if (!await dbFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قاعدة البيانات غير موجودة!', style: TextStyle(fontFamily: 'Cairo'))));
        }
        return;
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final backupPath = p.join(selectedDirectory, 'tager_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite');
      await dbFile.copy(backupPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم أخذ النسخة الاحتياطية بنجاح!\nالمسار: $backupPath', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء النسخ: $e', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _performRestore(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sqlite', 'db'],
      );

      if (result == null || result.files.single.path == null) return;

      final backupFile = File(result.files.single.path!);
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'app_db.sqlite'));

      await backupFile.copy(dbFile.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الاستعادة بنجاح! يرجى إعادة تشغيل التطبيق ليتم تحديث البيانات.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الاستعادة: $e', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.info, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text('حول النظام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40.r,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                child: Icon(LucideIcons.store, size: 40, color: AppColors.primary),
              ),
              SizedBox(height: 16.h),
              Text('نظام تاجر ERP (Tager ERP)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18.sp)),
              SizedBox(height: 8.h),
              Text('الإصدار: 1.0.0 (نطاق التطوير)', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              SizedBox(height: 16.h),
              Text(
                'نظام شامل لإدارة المبيعات، المشتريات، المخزون، الحسابات، ونقاط البيع (POS).',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    String title,
    IconData icon, {
    Widget? trailing,
    String? subtitle,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cairo',
                      color: iconColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  LucideIcons.chevronLeft,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
          ],
        ),
      ),
    );
  }
}

