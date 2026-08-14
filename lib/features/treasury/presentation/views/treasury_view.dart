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
    final categories = ref.watch(expenseCategoriesStreamProvider).value ?? [];
    final categoryNames = {for (final c in categories) c.id: c.name};

    final transactions = transactionsAsync.value ?? [];
    final shifts = shiftsAsync.value ?? [];
    final openShift = shifts.where((s) => s.status == 'open').firstOrNull;
    final treasuries = ref.watch(treasuryStreamProvider).value ?? [];
    final customers = ref.watch(customersStreamProvider).value ?? [];

    // درج الكاش هو الرصيد المعتمد، ومحفظتا فيزا/فوري مشتقتان من الحركات
    final drawerBalance = treasuries.isNotEmpty ? treasuries.first.currentBalance : 0.0;
    final cardBalance = _walletBalance(transactions, 'card');
    final fawryBalance = _walletBalance(transactions, 'fawry');

    // الشكك: أرصدة العملاء المدينة
    final debtors = customers.where((c) => c.balance > 0).toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    final totalDebts = debtors.fold<double>(0, (s, c) => s + c.balance);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

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
                    currentBalance: drawerBalance,
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

            // Wallet Cards
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
                              'رصيد درج الكاش الحالي',
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
                            '${drawerBalance.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28.sp,
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
                  child: _buildWalletCard(
                    title: 'محفظة فيزا / كارت',
                    amount: cardBalance,
                    icon: LucideIcons.creditCard,
                    color: AppColors.info,
                    onTransfer: cardBalance > 0.009
                        ? () => _showTransferDialog(context, db, 'card', cardBalance)
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: _buildWalletCard(
                    title: 'محفظة فوري',
                    amount: fawryBalance,
                    icon: LucideIcons.smartphone,
                    color: AppColors.warning,
                    onTransfer: fawryBalance > 0.009
                        ? () => _showTransferDialog(context, db, 'fawry', fawryBalance)
                        : null,
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

            // الشكك (البيع الآجل) panel
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, color: AppColors.warning, size: 22),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الشكك (بيع آجل): ${totalDebts.toStringAsFixed(2)} ج.م${debtors.isNotEmpty ? ' على ${debtors.length} عميل' : ''}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (debtors.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            debtors.take(3).map((c) => '${c.name}: ${c.balance.toStringAsFixed(2)} ج.م').join('  |  ') +
                                (debtors.length > 3 ? '  |  ...' : ''),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton.icon(
                    onPressed: debtors.isNotEmpty ? () => _showCollectDialog(context, db, debtors) : null,
                    icon: Icon(LucideIcons.coins, size: 18),
                    label: Text('تحصيل دفعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

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
                OutlinedButton.icon(
                  onPressed: () => _showCategoryBreakdownDialog(context, filteredTxs, categoryNames),
                  icon: Icon(LucideIcons.pieChart, size: 16),
                  label: Text('توزيع المصروفات بالفئات', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                ),
                SizedBox(width: 8.w),
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
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: _paymentBadgeColor(t.paymentMethod).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    _paymentMethodLabel(t.paymentMethod),
                                    style: TextStyle(
                                      color: _paymentBadgeColor(t.paymentMethod),
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'التاريخ: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(t.createdAt)} ${t.shiftId != null ? '| وردية #${t.shiftId}' : ''}${t.categoryId != null && categoryNames.containsKey(t.categoryId) ? ' | الفئة: ${categoryNames[t.categoryId]}' : ''}',
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

  void _showCategoryBreakdownDialog(
    BuildContext context,
    List<TreasuryTransaction> transactions,
    Map<int, String> categoryNames,
  ) {
    final expenses = transactions.where((t) => t.type.toUpperCase() == 'EXPENSE').toList();
    final Map<String, double> byCategory = {};
    for (final t in expenses) {
      final key = t.categoryId != null && categoryNames.containsKey(t.categoryId)
          ? categoryNames[t.categoryId]!
          : 'بدون فئة';
      byCategory[key] = (byCategory[key] ?? 0) + t.amount;
    }
    final entries = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = expenses.fold<double>(0, (s, t) => s + t.amount);

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.pieChart, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text('توزيع المصروفات حسب الفئات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 420.w,
            child: entries.isEmpty
                ? const Center(child: Text('لا توجد مصروفات في الفترة المحددة', style: TextStyle(fontFamily: 'Cairo')))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...entries.map(
                        (e) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          child: Row(
                            children: [
                              Expanded(child: Text(e.key, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
                              Text('${e.value.toStringAsFixed(2)} ج.م (${total == 0 ? 0 : (e.value / total * 100).toStringAsFixed(1)}%)',
                                  style: const TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 20.h),
                      Row(
                        children: [
                          const Expanded(child: Text('الإجمالي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                          Text('${total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, AppDatabase db, {required bool isIncome}) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String method = 'cash';

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
                  SizedBox(height: 16.h),
                  DropdownButtonFormField<String>(
                    initialValue: 'cash',
                    decoration: const InputDecoration(
                      labelText: 'طريقة الدفع',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('نقدي — درج الكاش', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'card', child: Text('فيزا / كارت', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'fawry', child: Text('فوري', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    onChanged: (v) => method = v ?? 'cash',
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
                      userId: ref.read(currentUserIdProvider) ?? 1,
                      description: desc.isNotEmpty ? desc : (isIncome ? 'إيداع نقدي' : 'صرف مصروفات'),
                      paymentMethod: method,
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

  double _walletBalance(List<TreasuryTransaction> txs, String method) {
    double balance = 0;
    for (final t in txs) {
      if (t.paymentMethod != method) continue;
      final type = t.type.toUpperCase();
      final isIn = type == 'INCOME' || type == 'SALE' || type == 'DEPOSIT' || type == 'IN';
      balance += isIn ? t.amount : -t.amount;
    }
    return balance;
  }

  String _paymentMethodLabel(String? method) {
    switch (method) {
      case 'card':
        return 'فيزا';
      case 'fawry':
        return 'فوري';
      case 'credit':
        return 'آجل';
      default:
        return 'نقدي';
    }
  }

  Color _paymentBadgeColor(String? method) {
    switch (method) {
      case 'card':
        return AppColors.info;
      case 'fawry':
        return AppColors.warning;
      case 'credit':
        return AppColors.error;
      default:
        return AppColors.success;
    }
  }

  Widget _buildWalletCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    VoidCallback? onTransfer,
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp, fontFamily: 'Cairo'),
                  overflow: TextOverflow.ellipsis,
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
              style: TextStyle(color: color, fontSize: 20.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTransfer,
              icon: Icon(LucideIcons.arrowLeftCircle, size: 14),
              label: Text('توريد للدرج', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp)),
              style: OutlinedButton.styleFrom(
                foregroundColor: onTransfer != null ? color : AppColors.textTertiary,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                padding: EdgeInsets.symmetric(vertical: 6.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context, AppDatabase db, String fromMethod, double walletBalance) {
    final amountController = TextEditingController(text: walletBalance.toStringAsFixed(2));
    final label = fromMethod == 'card' ? 'فيزا / كارت' : 'فوري';

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          title: Row(
            children: [
              Icon(LucideIcons.arrowLeftCircle, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                'توريد من محفظة $label إلى درج الكاش',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ],
          ),
          content: SizedBox(
            width: 420.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الرصيد المتاح في المحفظة: ${walletBalance.toStringAsFixed(2)} ج.م',
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13.sp),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المراد توريده (ج.م)',
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
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || amount > walletBalance + 0.009) {
                  AppErrorHandler.showErrorSnackBar(context, 'أدخل مبلغاً صحيحاً لا يتجاوز رصيد المحفظة');
                  return;
                }
                try {
                  await DbHelpers.transferWalletToDrawer(
                    db,
                    fromMethod: fromMethod,
                    amount: amount,
                    userId: ref.read(currentUserIdProvider) ?? 1,
                    notes: 'توريد من محفظة $label إلى درج الكاش',
                  );
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    AppErrorHandler.showSuccessSnackBar(context, 'تم توريد المبلغ إلى درج الكاش بنجاح');
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppErrorHandler.showErrorSnackBar(context, 'فشل التحويل: $e');
                  }
                }
              },
              child: Text('تأكيد التوريد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectDialog(BuildContext context, AppDatabase db, List<Customer> debtors) {
    final amountController = TextEditingController();
    Customer selected = debtors.first;
    String method = 'cash';

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          title: Row(
            children: [
              Icon(LucideIcons.coins, color: AppColors.success),
              SizedBox(width: 8.w),
              Text(
                'تحصيل دفعة من عميل (شكك)',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ],
          ),
          content: SizedBox(
            width: 450.w,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Customer>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'العميل المدين',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in debtors)
                        DropdownMenuItem(
                          value: c,
                          child: Text(
                            '${c.name} — عليه ${c.balance.toStringAsFixed(2)} ج.م',
                            style: TextStyle(fontFamily: 'Cairo'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) selected = v;
                    },
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المحصل (ج.م)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  DropdownButtonFormField<String>(
                    initialValue: 'cash',
                    decoration: const InputDecoration(
                      labelText: 'طريقة استلام الدفعة',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('نقدي — درج الكاش', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'card', child: Text('فيزا / كارت', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'fawry', child: Text('فوري', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    onChanged: (v) => method = v ?? 'cash',
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  AppErrorHandler.showErrorSnackBar(context, 'أدخل مبلغاً صحيحاً للتحصيل');
                  return;
                }
                try {
                  await DbHelpers.receiveCustomerPayment(
                    db,
                    customerId: selected.id,
                    amount: amount,
                    userId: ref.read(currentUserIdProvider) ?? 1,
                    paymentMethod: method,
                    notes: 'تحصيل من الشكك',
                  );
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    AppErrorHandler.showSuccessSnackBar(context, 'تم تحصيل الدفعة وتقليل مديونية العميل بنجاح');
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppErrorHandler.showErrorSnackBar(context, 'فشل التحصيل: $e');
                  }
                }
              },
              child: Text('تأكيد التحصيل', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
