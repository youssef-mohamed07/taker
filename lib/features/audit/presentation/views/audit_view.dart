import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';

class AuditView extends ConsumerWidget {
  const AuditView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogsAsync = ref.watch(auditLogsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سجل العمليات',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
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
                child: auditLogsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.fileText,
                              size: 48.sp,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'لا توجد أي عمليات مسجلة حتى الآن.',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: AppColors.textSecondary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 600,
                      headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
                      columns: const [
                        DataColumn2(label: Text('الوقت والتاريخ'), size: ColumnSize.L),
                        DataColumn2(label: Text('نوع العملية'), size: ColumnSize.S),
                        DataColumn2(label: Text('الجدول المستهدف'), size: ColumnSize.M),
                        DataColumn2(label: Text('رقم المستخدم'), size: ColumnSize.S),
                        DataColumn2(label: Text('التفاصيل'), size: ColumnSize.S),
                      ],
                      rows: logs.map((log) {
                        return DataRow(
                          cells: [
                            DataCell(Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt),
                              style: TextStyle(fontSize: 14.sp),
                            )),
                            DataCell(_buildActionBadge(context, log.action)),
                            DataCell(Text(
                              log.targetTable,
                              style: TextStyle(fontSize: 14.sp),
                            )),
                            DataCell(Text(
                              '${log.userId}',
                              style: TextStyle(fontSize: 14.sp),
                            )),
                            DataCell(
                              TextButton.icon(
                                onPressed: () => _showDetailsDialog(context, log),
                                icon: Icon(LucideIcons.eye, size: 16.sp),
                                label: Text('عرض', style: TextStyle(fontSize: 14.sp)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                  loading: () => Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(
                      'حدث خطأ في جلب البيانات: $err',
                      style: TextStyle(color: AppColors.error, fontSize: 14.sp),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBadge(BuildContext context, String action) {
    Color bgColor;
    Color textColor;
    String label;

    switch (action.toUpperCase()) {
      case 'CREATE':
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green[800]!;
        label = 'إضافة';
        break;
      case 'UPDATE':
        bgColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue[800]!;
        label = 'تعديل';
        break;
      case 'DELETE':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red[800]!;
        label = 'حذف';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey[800]!;
        label = action;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, dynamic log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تفاصيل العملية (رقم ${log.id})',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 500.w,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(context, 'الجدول:', log.targetTable),
                _buildDetailRow(context, 'رقم السجل:', log.recordId?.toString() ?? 'غير محدد'),
                SizedBox(height: 16.h),
                if (log.oldData != null && log.oldData!.isNotEmpty) ...[
                  Text('البيانات القديمة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Text(log.oldData!, style: TextStyle(fontFamily: 'Courier', fontSize: 12.sp)),
                  ),
                  SizedBox(height: 16.h),
                ],
                if (log.newData != null && log.newData!.isNotEmpty) ...[
                  Text('البيانات الجديدة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Text(log.newData!, style: TextStyle(fontFamily: 'Courier', fontSize: 12.sp)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
