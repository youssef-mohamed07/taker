import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';

class TreasuryView extends ConsumerStatefulWidget {
  const TreasuryView({super.key});

  @override
  ConsumerState<TreasuryView> createState() => _TreasuryViewState();
}

class _TreasuryViewState extends ConsumerState<TreasuryView> {
  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(treasuryTransactionsStreamProvider);
    final db = ref.watch(databaseProvider);

    final transactions = transactionsAsync.value ?? [];

    final totalIncome = transactions
        .where((t) {
          final type = t.type.toUpperCase();
          return type == 'INCOME' || type == 'SALE' || type == 'DEPOSIT' || type == 'IN';
        })
        .fold<double>(0, (sum, t) => sum + t.amount);

    final totalExpense = transactions
        .where((t) {
          final type = t.type.toUpperCase();
          return type == 'EXPENSE' || type == 'PURCHASE' || type == 'WITHDRAW' || type == 'WITHDRAWAL' || type == 'OUT';
        })
        .fold<double>(0, (sum, t) => sum + t.amount);

    final currentBalance = totalIncome - totalExpense;

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
                        'إدارة الخزنة والنقدية',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'متابعة حركة النقدية، الإيداعات، السحوبات، والمصروفات اليومية',
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
                  onPressed: () => _showAddTransactionDialog(context, db, isIncome: true),
                  icon: Icon(LucideIcons.arrowDownCircle, size: 18),
                  label: Text('سند قبض (إيداع)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton.icon(
                  onPressed: () => _showAddTransactionDialog(context, db, isIncome: false),
                  icon: Icon(LucideIcons.arrowUpCircle, size: 18),
                  label: Text('سند صرف (مصروفات)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Balance Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إجمالي رصيد الخزنة الحالي',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14.sp,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currentBalance.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'إجمالي المقبوضات: +${totalIncome.toStringAsFixed(2)} ج.م',
                        style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'إجمالي المصروفات: -${totalExpense.toStringAsFixed(2)} ج.م',
                        style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 13.sp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            Text(
              'سجل حركات الخزنة النقدية',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),

            // Transactions Table
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: transactions.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد حركات في الخزنة حتى الآن',
                          style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Cairo'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => Divider(height: 1.h),
                        itemBuilder: (context, index) {
                          final t = transactions[index];
                          final typeUpper = t.type.toUpperCase();
                          final isInc = typeUpper == 'INCOME' || typeUpper == 'SALE' || typeUpper == 'DEPOSIT' || typeUpper == 'IN';

                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                            leading: Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: isInc ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                isInc ? LucideIcons.arrowDownCircle : LucideIcons.arrowUpCircle,
                                color: isInc ? AppColors.success : AppColors.error,
                                size: 22,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.description ?? (isInc ? 'إيداع/قبض نقدي' : 'صرف/مصروفات'),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: isInc ? AppColors.successLight : AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    t.type.toUpperCase(),
                                    style: TextStyle(
                                      color: isInc ? AppColors.success : AppColors.error,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'التاريخ: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(t.createdAt)}',
                              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12.sp),
                            ),
                            trailing: Text(
                              '${isInc ? '+' : '-'}${t.amount.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: isInc ? AppColors.success : AppColors.error,
                              ),
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

  void _showAddTransactionDialog(BuildContext context, AppDatabase db, {required bool isIncome}) {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  isIncome ? LucideIcons.arrowDownCircle : LucideIcons.arrowUpCircle,
                  color: isIncome ? AppColors.success : AppColors.error,
                ),
                SizedBox(width: 8.w),
                Text(
                  isIncome ? 'سند قبض / إيداع جديد' : 'سند صرف / مصروف جديد',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 450.w,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ (ج.م)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'البيان / الوصف (مثال: سداد مصروفات كهراباء أو صيانة)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isIncome ? AppColors.success : AppColors.error),
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  final desc = descController.text.trim();
                  if (amount > 0) {
                    await DbHelpers.addTreasuryTransaction(
                      db,
                      type: isIncome ? 'INCOME' : 'EXPENSE',
                      amount: amount,
                      userId: 1,
                      description: desc.isNotEmpty ? desc : (isIncome ? 'إيداع نقدي' : 'صرف مصروفات'),
                    );
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم تسجيل الحركة في الخزنة بنجاح!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  }
                },
                child: Text('تسجيل الحركة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
