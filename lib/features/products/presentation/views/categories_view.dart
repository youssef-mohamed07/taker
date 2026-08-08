import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_error_handler.dart';

class CategoriesView extends ConsumerStatefulWidget {
  const CategoriesView({super.key});

  @override
  ConsumerState<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends ConsumerState<CategoriesView> {
  void _showAddEditDialog(BuildContext context, AppDatabase db, {Category? category}) {
    final nameCtrl = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Row(
            children: [
              Icon(
                category == null ? LucideIcons.folderPlus : LucideIcons.edit2,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Text(
                category == null ? 'إضافة تصنيف جديد' : 'تعديل التصنيف',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 400.w,
            child: TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم التصنيف',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  AppErrorHandler.showErrorSnackBar(context, 'اسم التصنيف مطلوب');
                  return;
                }

                try {
                  if (category == null) {
                    await db.into(db.categories).insert(
                          CategoriesCompanion.insert(name: name),
                        );
                  } else {
                    await (db.update(db.categories)..where((t) => t.id.equals(category.id))).write(
                      CategoriesCompanion(name: drift.Value(name)),
                    );
                  }
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                    AppErrorHandler.showSuccessSnackBar(context, 'تم حفظ التصنيف بنجاح');
                  }
                } catch (e) {
                  if (dialogCtx.mounted) {
                    AppErrorHandler.showErrorDialog(context, e, title: 'خطأ في حفظ التصنيف');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('حفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppDatabase db, Category category) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Row(
            children: [
              Icon(LucideIcons.trash2, color: AppColors.error),
              SizedBox(width: 8.w),
              Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف التصنيف "${category.name}"؟\nتنبيه: لا يمكن حذف التصنيف إذا كان مرتبطاً بمنتجات.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Check if products use this category
                  final productsUsingIt = await (db.select(db.products)
                        ..where((t) => t.categoryId.equals(category.id)))
                      .get();
                      
                  if (productsUsingIt.isNotEmpty) {
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      AppErrorHandler.showErrorSnackBar(
                          context, 'لا يمكن حذف التصنيف، يوجد ${productsUsingIt.length} منتجات مرتبطة به');
                    }
                    return;
                  }

                  await (db.delete(db.categories)..where((t) => t.id.equals(category.id))).go();
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                    AppErrorHandler.showSuccessSnackBar(context, 'تم حذف التصنيف بنجاح');
                  }
                } catch (e) {
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                    AppErrorHandler.showErrorDialog(context, e, title: 'خطأ في الحذف');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final db = ref.watch(databaseProvider);

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تصنيفات المنتجات',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'إدارة وتنظيم مجموعات الأصناف',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditDialog(context, db),
                  icon: Icon(LucideIcons.plus, size: 18),
                  label: Text('إضافة تصنيف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.folders, size: 48, color: AppColors.textTertiary),
                            SizedBox(height: 16.h),
                            Text(
                              'لا توجد تصنيفات بعد',
                              style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: SingleChildScrollView(
                        child: DataTable(
                          headingTextStyle: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                          ),
                          dataTextStyle: TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                          ),
                          columnSpacing: 100.w,
                          horizontalMargin: 24.w,
                          dividerThickness: 1.h,
                          showBottomBorder: true,
                          columns: const [
                            DataColumn(label: Text('رقم التصنيف')),
                            DataColumn(label: Text('اسم التصنيف')),
                            DataColumn(label: Text('إجراءات')),
                          ],
                          rows: categories.map((cat) {
                            return DataRow(
                              cells: [
                                DataCell(Text('#${cat.id}', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.folder, size: 20, color: AppColors.primary),
                                      SizedBox(width: 8.w),
                                      Text(cat.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(LucideIcons.edit2, color: AppColors.primary, size: 20),
                                        onPressed: () => _showAddEditDialog(context, db, category: cat),
                                        tooltip: 'تعديل',
                                      ),
                                      IconButton(
                                        icon: Icon(LucideIcons.trash2, color: AppColors.error, size: 20),
                                        onPressed: () => _confirmDelete(context, db, cat),
                                        tooltip: 'حذف',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      ),
                    );
                  },
                 );
                },
                  loading: () => Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('خطأ: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
