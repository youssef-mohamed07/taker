import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';

class PartnersView extends ConsumerStatefulWidget {
  const PartnersView({super.key});

  @override
  ConsumerState<PartnersView> createState() => _PartnersViewState();
}

class _PartnersViewState extends ConsumerState<PartnersView> {
  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnersStreamProvider);
    final db = ref.watch(databaseProvider);

    final partners = partnersAsync.value ?? [];
    final totalCapital = partners.fold<double>(0, (sum, p) => sum + p.capital);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة الشركاء والحصص',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'متابعة الشركاء، النسبة المئوية ورأس المال وتوزيعات الأرباح',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddPartnerDialog(context, db),
                  icon: Icon(LucideIcons.userPlus, size: 18),
                  label: Text('إضافة شريك جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Capital Metric
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(LucideIcons.landmark, color: AppColors.primary, size: 24),
                  ),
                  SizedBox(width: 16.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي رأس مال الشركاء المسجل',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${totalCapital.toStringAsFixed(2)} ج.م',
                        style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'عدد الشركاء: ${partners.length}',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Partners List
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: partners.isEmpty
                    ? Center(
                        child: Text(
                          'لا يوجد شركاء مسجلين بالنظام حتى الآن',
                          style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Cairo'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: partners.length,
                        separatorBuilder: (_, __) => Divider(height: 1.h),
                        itemBuilder: (context, index) {
                          final p = partners[index];
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                            leading: Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(LucideIcons.user, color: AppColors.primary, size: 22),
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15.sp),
                            ),
                            subtitle: Text(
                              'رأس المال: ${p.capital.toStringAsFixed(2)} ج.م | نسبة الشراكة: ${p.sharePercentage}% | تاريخ التسجيل: ${intl.DateFormat('yyyy/MM/dd').format(p.createdAt)}',
                              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12.sp),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    '${p.sharePercentage}%',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14.sp),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                IconButton(
                                  icon: Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: AlertDialog(
                                          title: Text('حذف الشريك', style: TextStyle(fontFamily: 'Cairo')),
                                          content: Text('هل أنت تأكد من حذف الشريك ${p.name}؟', style: TextStyle(fontFamily: 'Cairo')),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: Text('حذف', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (confirm == true) {
                                      await (db.delete(db.partners)..where((tbl) => tbl.id.equals(p.id))).go();
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPartnerDialog(BuildContext context, AppDatabase db) {
    final nameController = TextEditingController();
    final percentageController = TextEditingController(text: '50');
    final capitalController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(LucideIcons.userPlus, color: AppColors.primary),
                SizedBox(width: 8.w),
                Text('إضافة شريك جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 450.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الشريك الثلاثي',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: percentageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة الشراكة (%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: capitalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المساهم به (رأس المال)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final perc = double.tryParse(percentageController.text) ?? 0;
                  final cap = double.tryParse(capitalController.text) ?? 0;

                  if (name.isNotEmpty) {
                    await db.into(db.partners).insert(
                          PartnersCompanion.insert(
                            name: name,
                            sharePercentage: perc,
                            capital: drift.Value(cap),
                          ),
                        );
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم تسجيل الشريك $name بنجاح!'), backgroundColor: AppColors.success),
                      );
                    }
                  }
                },
                child: Text('حفظ الشريك', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
