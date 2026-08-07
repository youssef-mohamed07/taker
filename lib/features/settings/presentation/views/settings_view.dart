import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';

import '../../../../core/database/db_helpers.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الإعدادات',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 12),
            _buildSettingCard(
              'المستخدمون',
              LucideIcons.userCog,
              subtitle: 'إدارة الحسابات والصلاحيات',
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              'الطابعة',
              LucideIcons.printer,
              subtitle: 'إعدادات الطابعة الحرارية',
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              'النسخ الاحتياطي',
              LucideIcons.hardDrive,
              subtitle: 'Backup & Restore',
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              'تصفير وإعادة ضبط البيانات',
              LucideIcons.trash2,
              subtitle: 'مسح كافة البيانات الوهمية والتجريبية لتسليم التطبيق',
              iconColor: Colors.red,
              onTap: () => _showResetDatabaseDialog(context, db),
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              'حول البرنامج',
              LucideIcons.info,
              subtitle: 'الإصدار 1.0.0',
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDatabaseDialog(BuildContext context, db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.red),
            SizedBox(width: 8),
            Text('تصفير قاعدة البيانات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'هل أنت تأكد من رغبتك في تصفير كافة البيانات؟\nسيتم مسح المنتجات، الفواتير، المبيعات، المشتريات، الشيفتات والحركات المالية نهائياً لتسليم النطام بحالة نظيفة.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
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
            child: const Text('تأكيد التصفير', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                const Icon(
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

