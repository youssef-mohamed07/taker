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

class TreasuryView extends ConsumerStatefulWidget {
  const TreasuryView({super.key});

  @override
  ConsumerState<TreasuryView> createState() => _TreasuryViewState();
}

class _TreasuryViewState extends ConsumerState<TreasuryView> {
  String _filter = 'TODAY'; // ALL, TODAY, SHIFT

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(treasuryTransactionsStreamProvider);
    final shiftsAsync = ref.watch(shiftsStreamProvider);
    final db = ref.watch(databaseProvider);

    final transactions = transactionsAsync.value ?? [];
    final shifts = shiftsAsync.value ?? [];
    final openShift = shifts.where((s) => s.status == 'open').firstOrNull;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Calculate totals overall
    final totalIncomeAll = transactions
        .where((t) {
          final type = t.type.toUpperCase();
          return type == 'INCOME' || type == 'SALE' || type == 'DEPOSIT' || type == 'IN';
        })
        .fold<double>(0, (sum, t) => sum + t.amount);

    final totalExpenseAll = transactions
        .where((t) {
          final type = t.type.toUpperCase();
          return type == 'EXPENSE' || type == 'PURCHASE' || type == 'WITHDRAW' || type == 'WITHDRAWAL' || type == 'OUT';
        })
        .fold<double>(0, (sum, t) => sum + t.amount);

    final currentBalance = totalIncomeAll - totalExpenseAll;

    // Today's metrics
    final todayTxs = transactions.where((t) => t.createdAt.isAfter(todayStart)).toList();
    final todayIncome = todayTxs
        .where((t) {
          final type = t.type.toUpperCase();
          return type == 'INCOME' || type == 'SALE' || type == 'DEPOSIT' || type == 'IN';
        })
        .fold<double>(0, (sum, t) => sum + t.amount);

    final todayExpense = todayTxs
        .where((t) {
          final type = t.type.toUpperCase();
          return type == 'EXPENSE' || type == 'PURCHASE' || type == 'WITHDRAW' || type == 'WITHDRAWAL' || type == 'OUT';
        })
        .fold<double>(0, (sum, t) => sum + t.amount);

    // Active Shift metrics
    double shiftIncome = 0;
    double shiftExpense = 0;
    if (openShift != null) {
      final shiftTxs = transactions.where((t) =>
          t.shiftId == openShift.id ||
          (t.createdAt.isAfter(openShift.openedAt) && t.shiftId == null));
      for (final tx in shiftTxs) {
        final typeUpper = tx.type.toUpperCase();
        if (typeUpper == 'INCOME' || typeUpper == 'SALE' || typeUpper == 'DEPOSIT' || typeUpper == 'IN') {
          shiftIncome += tx.amount;
        } else {
          shiftExpense += tx.amount;
        }
      }
    }

    // Filtered list
    final filteredTxs = transactions.where((t) {
      if (_filter == 'TODAY') {
        return t.createdAt.isAfter(todayStart);
      } else if (_filter == 'SHIFT') {
        if (openShift == null) return false;
        return t.shiftId == openShift.id || t.createdAt.isAfter(openShift.openedAt);
      }
      return true;
    }).toList();

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
                        'إدارة الخزنة واليومية',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'متابعة حركة النقدية اليومية، الشيفت الحالي، والإيداعات والمصروفات',
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
                  onPressed: () => _showDailySummaryDialog(
                    context,
                    todayIncome: todayIncome,
                    todayExpense: todayExpense,
                    currentBalance: currentBalance,
                    openShift: openShift,
                  ),
                  icon: Icon(LucideIcons.fileSpreadsheet, size: 18),
                  label: Text('تصفية وتقفيلة اليوم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
                SizedBox(width: 8.w),
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
            SizedBox(height: 20.h),

            // Top Summary Cards
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'رصيد الخزنة الكلي الحالي',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.sp,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Icon(LucideIcons.wallet, color: Colors.white, size: 22),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currentBalance.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: _buildTodayCard(
                    title: 'مقبوضات اليوم (+)',
                    amount: todayIncome,
                    color: AppColors.success,
                    icon: LucideIcons.trendingUp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: _buildTodayCard(
                    title: 'مصروفات اليوم (-)',
                    amount: todayExpense,
                    color: AppColors.error,
                    icon: LucideIcons.trendingDown,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: _buildTodayCard(
                    title: 'صافي نقدية اليوم',
                    amount: todayIncome - todayExpense,
                    color: (todayIncome - todayExpense) >= 0 ? AppColors.success : AppColors.error,
                    icon: LucideIcons.coins,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Active Shift Status Line inside Treasury
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: openShift != null ? AppColors.success : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    openShift != null ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                    color: openShift != null ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      openShift != null
                          ? 'الشيفت النشط: وردية #${openShift.id} | رصيد البداية: ${openShift.openingBalance.toStringAsFixed(2)} ج.م | المتوقع حالياً: ${(openShift.openingBalance + shiftIncome - shiftExpense).toStringAsFixed(2)} ج.م'
                          : 'لا يوجد شيفت مفتوح حالياً. يمكنك تتبع النقدية أو فتح شيفت جديد من إدارة الشيفتات.',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Transactions Header & Filters
            Row(
              children: [
                Text(
                  'سجل حركات الخزنة والنقدية',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'TODAY',
                      label: Text('حركات اليوم', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 'SHIFT',
                      label: Text('الشيفت الحالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 'ALL',
                      label: Text('كل الحركات', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _filter = newSelection.first;
                    });
                  },
                ),
              ],
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
                child: filteredTxs.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد حركات نقدية تطابق التصفية الحالية',
                          style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Cairo', fontSize: 15.sp),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredTxs.length,
                        separatorBuilder: (_, __) => Divider(height: 1.h),
                        itemBuilder: (context, index) {
                          final t = filteredTxs[index];
                          final typeUpper = t.type.toUpperCase();
                          final isInc = typeUpper == 'INCOME' || typeUpper == 'SALE' || typeUpper == 'DEPOSIT' || typeUpper == 'IN';

                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                            leading: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: isInc ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Icon(
                                isInc ? LucideIcons.arrowDownCircle : LucideIcons.arrowUpCircle,
                                color: isInc ? AppColors.success : AppColors.error,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.description ?? (isInc ? 'إيداع/قبض نقدي' : 'صرف/مصروفات'),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14.sp),
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
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'التاريخ: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(t.createdAt)} ${t.shiftId != null ? '| وردية #${t.shiftId}' : ''}',
                              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12.sp),
                            ),
                            trailing: Text(
                              '${isInc ? '+' : '-'}${t.amount.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
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

  Widget _buildTodayCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontFamily: 'Cairo',
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          SizedBox(height: 6.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${amount.toStringAsFixed(2)} ج.م',
              style: TextStyle(
                color: color,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDailySummaryDialog(
    BuildContext context, {
    required double todayIncome,
    required double todayExpense,
    required double currentBalance,
    required Shift? openShift,
  }) {
    final todayNet = todayIncome - todayExpense;
    final dateStr = intl.DateFormat('yyyy/MM/dd').format(DateTime.now());

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          title: Row(
            children: [
              Icon(LucideIcons.fileSpreadsheet, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                'تقرير تقفيلة وتصفية اليوم ($dateStr)',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ],
          ),
          content: SizedBox(
            width: 450.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('إجمالي مقبوضات ومبيعات اليوم:', style: TextStyle(fontFamily: 'Cairo', fontSize: 14.sp)),
                          Text('+${todayIncome.toStringAsFixed(2)} ج.م',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 14.sp)),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('إجمالي مصروفات اليوم:', style: TextStyle(fontFamily: 'Cairo', fontSize: 14.sp)),
                          Text('-${todayExpense.toStringAsFixed(2)} ج.م',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 14.sp)),
                        ],
                      ),
                      Divider(height: 20.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('صافي الحركة المالية لليوم:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14.sp)),
                          Text('${todayNet.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  color: todayNet >= 0 ? AppColors.success : AppColors.error,
                                  fontSize: 15.sp)),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('رصيد الخزنة الإجمالي المتاح:', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                          Text('${currentBalance.toStringAsFixed(2)} ج.م',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16.sp)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                if (openShift != null)
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 20),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'تنبيه: يوجد وردية نشطة حالياً (#${openShift.id}). يفضل إغلاق الوردية قبل اعتماد التصفية الكلية.',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إغلاق التقرير', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () {
                Navigator.pop(dialogCtx);
                AppErrorHandler.showSuccessSnackBar(context, 'تمت مراجعة وتصفية حسابات اليوم بنجاح!');
              },
              icon: const Icon(LucideIcons.checkCheck, size: 18),
              label: Text('اعتماد تصفية اليوم', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
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
