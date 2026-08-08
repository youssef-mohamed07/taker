import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/errors/app_error_handler.dart';

class ShiftsView extends ConsumerStatefulWidget {
  const ShiftsView({super.key});

  @override
  ConsumerState<ShiftsView> createState() => _ShiftsViewState();
}

class _ShiftsViewState extends ConsumerState<ShiftsView> {
  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(shiftsStreamProvider);
    final txsAsync = ref.watch(treasuryTransactionsStreamProvider);
    final db = ref.watch(databaseProvider);

    final shifts = shiftsAsync.value ?? [];
    final openShift = shifts.where((s) => s.status == 'open').firstOrNull;
    final allTxs = txsAsync.value ?? [];

    double shiftIncome = 0.0;
    double shiftExpense = 0.0;
    double expectedTreasury = 0.0;

    if (openShift != null) {
      final shiftTxs = allTxs.where((tx) =>
          tx.shiftId == openShift.id ||
          (tx.createdAt.isAfter(openShift.openedAt) && tx.shiftId == null));

      for (final tx in shiftTxs) {
        if (tx.type == 'INCOME' || tx.type == 'DEPOSIT') {
          shiftIncome += tx.amount;
        } else if (tx.type == 'EXPENSE' || tx.type == 'WITHDRAWAL') {
          shiftExpense += tx.amount;
        }
      }
      expectedTreasury = openShift.openingBalance + shiftIncome - shiftExpense;
    }

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
                        'إدارة الشيفتات والورديات',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'متابعة النقدية عند استلام وتسليم الخزنة لكل وردية',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                if (openShift == null)
                  ElevatedButton.icon(
                    onPressed: () => _showOpenShiftDialog(context, db),
                    icon: Icon(LucideIcons.play, size: 18),
                    label: Text('فتح شيفت جديد',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _showCloseShiftDialog(context, db, openShift, expectedTreasury),
                    icon: Icon(LucideIcons.square, size: 18),
                    label: Text('غلق الشيفت الحالي',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 24.h),

            // Active Shift Status Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: openShift != null ? AppColors.success : AppColors.border,
                  width: openShift != null ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: (openShift != null ? AppColors.success : AppColors.warning)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          openShift != null ? LucideIcons.checkCircle : LucideIcons.clock,
                          color: openShift != null ? AppColors.success : AppColors.warning,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              openShift != null
                                  ? 'حالة الوردية: شيفت نشط حالياً (#${openShift.id})'
                                  : 'حالة الوردية: لا يوجد شيفت مفتوح',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              openShift != null
                                  ? 'تم الفتح بتاريخ: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(openShift.openedAt)}'
                                  : 'اضغط على زر "فتح شيفت جديد" لبدء الوردية وتحديد رصيد البداية بالخزنة',
                              style: TextStyle(
                                  fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (openShift != null) ...[
                    SizedBox(height: 16.h),
                    Divider(height: 1.h),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            title: 'الرصيد الافتتاحي',
                            value: '${openShift.openingBalance.toStringAsFixed(2)} ج.م',
                            icon: LucideIcons.wallet,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildMetricTile(
                            title: 'مقبوضات الشيفت (+)',
                            value: '${shiftIncome.toStringAsFixed(2)} ج.م',
                            icon: LucideIcons.arrowDownLeft,
                            color: AppColors.success,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildMetricTile(
                            title: 'مصروفات الشيفت (-)',
                            value: '${shiftExpense.toStringAsFixed(2)} ج.م',
                            icon: LucideIcons.arrowUpRight,
                            color: AppColors.error,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildMetricTile(
                            title: 'المتوقع بالخزنة الآن',
                            value: '${expectedTreasury.toStringAsFixed(2)} ج.م',
                            icon: LucideIcons.badgeCheck,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24.h),

            Text(
              'سجل الشيفتات والورديات السابقة',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),

            // Shifts List Table
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: shifts.isEmpty
                    ? Center(
                        child: Text(
                          'لا يوجد سجل شيفتات بعد',
                          style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Cairo'),
                        ),
                      )
                    : LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(constraints: BoxConstraints(minWidth: constraints.maxWidth), child: SingleChildScrollView(
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
                            columnSpacing: 60.w,
                            horizontalMargin: 24.w,
                            dividerThickness: 1.h,
                            showBottomBorder: true,
                            columns: const [
                              DataColumn(label: Text('الشيفت')),
                              DataColumn(label: Text('الحالة')),
                              DataColumn(label: Text('الفترة الزمنية')),
                              DataColumn(label: Text('الرصيد الافتتاحي')),
                              DataColumn(label: Text('رصيد الإغلاق')),
                              DataColumn(label: Text('الفارق')),
                            ],
                            rows: shifts.map((s) {
                              final isOpen = s.status == 'open';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8.w),
                                          decoration: BoxDecoration(
                                            color: (isOpen ? AppColors.success : AppColors.primary).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Icon(
                                            isOpen ? LucideIcons.play : LucideIcons.checkCheck,
                                            color: isOpen ? AppColors.success : AppColors.primary,
                                            size: 16,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text('شيفت #${s.id}', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: isOpen ? AppColors.successLight : AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        isOpen ? 'مفتوح' : 'مغلق',
                                        style: TextStyle(
                                          color: isOpen ? AppColors.success : AppColors.textSecondary,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${intl.DateFormat('yyyy/MM/dd HH:mm').format(s.openedAt)} '
                                      '${s.closedAt != null ? '- ${intl.DateFormat('HH:mm').format(s.closedAt!)}' : ''}',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
                                    ),
                                  ),
                                  DataCell(Text('${s.openingBalance.toStringAsFixed(2)} ج.م', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(
                                    s.closingBalance != null
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${s.closingBalance!.toStringAsFixed(2)} ج.م', style: TextStyle(fontWeight: FontWeight.bold)),
                                              Text('المتوقع: ${(s.expectedBalance ?? 0).toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary)),
                                            ],
                                          )
                                        : Text('---', style: TextStyle(color: AppColors.textTertiary)),
                                  ),
                                  DataCell(
                                    s.closingBalance != null && (s.difference ?? 0) != 0
                                        ? Text(
                                            '${s.difference! > 0 ? '+' : ''}${s.difference!.toStringAsFixed(2)} ج.م',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: s.difference! < 0 ? AppColors.error : AppColors.success,
                                            ),
                                          )
                                        : Text(s.closingBalance != null ? 'متطابق' : '---', style: TextStyle(color: AppColors.textSecondary)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        )),
                      )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenShiftDialog(BuildContext context, AppDatabase db) {
    final balanceController = TextEditingController(text: '0');
    List<String> selectedCompanions = [];
    bool isLoadingPartners = true;
    List<Partner> partners = [];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoadingPartners) {
              db.select(db.partners).get().then((value) {
                if (mounted) {
                  setState(() {
                    partners = value;
                    isLoadingPartners = false;
                  });
                }
              });
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(LucideIcons.play, color: AppColors.success),
                    SizedBox(width: 8.w),
                    Text('فتح وردية جديدة',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SizedBox(
                  width: 450.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: balanceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ الافتتاحي بالخزنة (ج.م)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text('شركاء / مرافقين الشيفت (اختياري):', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14.sp)),
                        SizedBox(height: 8.h),
                        if (isLoadingPartners)
                          const Center(child: CircularProgressIndicator())
                        else if (partners.isEmpty)
                          Text('لا يوجد شركاء مضافين حالياً.', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13.sp))
                        else
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: partners.map((p) {
                              final isSelected = selectedCompanions.contains(p.name);
                              return FilterChip(
                                label: Text(p.name, style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp, color: isSelected ? Colors.white : AppColors.textPrimary)),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                checkmarkColor: Colors.white,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedCompanions.add(p.name);
                                    } else {
                                      selectedCompanions.remove(p.name);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text('إلغاء',
                        style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: () async {
                      final opening = double.tryParse(balanceController.text) ?? 0;
                      final companionNames = selectedCompanions.isNotEmpty ? selectedCompanions.join(', ') : null;
                      try {
                        await DbHelpers.openShift(db, openingBalance: opening, userId: 1, companionNames: companionNames);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          AppErrorHandler.showSuccessSnackBar(context, 'تم فتح الوردية بنجاح!');
                        }
                      } catch (e) {
                        if (dialogCtx.mounted) {
                          AppErrorHandler.showErrorDialog(context, e, title: 'خطأ في فتح الوردية');
                        }
                      }
                    },
                    child: Text('فتح الشيفت',
                        style: TextStyle(
                            fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showCloseShiftDialog(
      BuildContext context, AppDatabase db, Shift shift, double expectedBalance) {
    final closingController = TextEditingController(text: expectedBalance.toStringAsFixed(2));
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(LucideIcons.square, color: AppColors.error),
                SizedBox(width: 8.w),
                Text('إغلاق الوردية الحالية',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 420.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الرصيد الافتتاحي:', style: TextStyle(fontFamily: 'Cairo')),
                            Text('${shift.openingBalance.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('المبلغ المتوقع توفره بالخزنة:',
                                style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
                            Text('${expectedBalance.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: closingController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الفعلي الموجود بالخزنة عند الإغلاق (ج.م)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الإغلاق (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () async {
                  try {
                    final closing = double.tryParse(closingController.text) ?? expectedBalance;
                    await DbHelpers.closeShift(
                      db,
                      shiftId: shift.id,
                      closingBalance: closing,
                      notes: notesController.text.isNotEmpty ? notesController.text : null,
                    );

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      AppErrorHandler.showSuccessSnackBar(
                          context, 'تم إغلاق الشيفت وتسوية الحسابات بنجاح!');
                    }
                  } catch (e) {
                    if (dialogCtx.mounted) {
                      AppErrorHandler.showErrorDialog(context, e, title: 'خطأ في إغلاق الوردية');
                    }
                  }
                },
                child: Text(
                  'تأكيد الإغلاق',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}










