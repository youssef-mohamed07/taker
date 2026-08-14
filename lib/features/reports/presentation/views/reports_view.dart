import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  DateTime? _from;
  DateTime? _to;

  bool _inRange(DateTime dt) {
    if (_from != null && dt.isBefore(_from!)) return false;
    if (_to != null && dt.isAfter(_to!.add(const Duration(days: 1)))) {
      return false;
    }
    return true;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSales = ref.watch(salesInvoicesStreamProvider).value ?? [];
    final allPurchases = ref.watch(purchaseInvoicesStreamProvider).value ?? [];
    final products = ref.watch(productsStreamProvider).value ?? [];
    final allTreasuryTx =
        ref.watch(treasuryTransactionsStreamProvider).value ?? [];
    final invoiceItems = ref.watch(invoiceItemsStreamProvider).value ?? [];
    final customers = ref.watch(customersStreamProvider).value ?? [];
    final suppliers = ref.watch(suppliersStreamProvider).value ?? [];

    // Exclude voided invoices and apply the date range.
    final salesInvoices = allSales
        .where((i) => i.status != 'voided' && _inRange(i.createdAt))
        .toList();
    final purchaseInvoices = allPurchases
        .where((i) => i.status != 'voided' && _inRange(i.createdAt))
        .toList();
    final treasuryTx =
        allTreasuryTx.where((t) => _inRange(t.createdAt)).toList();

    // Real profit from invoice items of non-voided, in-range invoices.
    final validInvoiceIds = salesInvoices.map((i) => i.id).toSet();
    double totalCost = 0.0;
    double totalSalesOfItems = 0.0;
    for (final item in invoiceItems) {
      if (!validInvoiceIds.contains(item.invoiceId)) continue;
      totalSalesOfItems += item.total;
      totalCost += item.costPrice * item.quantity;
    }
    final realProfit = totalSalesOfItems - totalCost;

    final totalSales =
        salesInvoices.fold<double>(0, (s, i) => s + i.total);
    final totalPurchases =
        purchaseInvoices.fold<double>(0, (s, p) => s + p.total);
    final totalIncome = treasuryTx
        .where((t) => t.type == 'INCOME' || t.type == 'DEPOSIT')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalExpense = treasuryTx
        .where((t) => t.type == 'EXPENSE' || t.type == 'WITHDRAWAL')
        .fold<double>(0, (s, t) => s + t.amount);

    // Sales breakdown per payment method
    double salesCash = 0, salesCard = 0, salesFawry = 0, salesCredit = 0;
    for (final i in salesInvoices) {
      switch (i.paymentMethod) {
        case 'card':
          salesCard += i.total;
        case 'fawry':
          salesFawry += i.total;
        case 'credit':
          salesCredit += i.total;
        default:
          salesCash += i.total;
      }
    }

    // Treasury movements per payment channel
    double inCash = 0, inCard = 0, inFawry = 0;
    double outCash = 0, outCard = 0, outFawry = 0;
    for (final t in treasuryTx) {
      final isIn = t.type == 'INCOME' || t.type == 'DEPOSIT';
      final isOut = t.type == 'EXPENSE' || t.type == 'WITHDRAWAL';
      if (!isIn && !isOut) continue;
      final pm = t.paymentMethod ?? 'cash';
      if (pm == 'card') {
        if (isIn) inCard += t.amount;
        else outCard += t.amount;
      } else if (pm == 'fawry') {
        if (isIn) inFawry += t.amount;
        else outFawry += t.amount;
      } else {
        if (isIn) inCash += t.amount;
        else outCash += t.amount;
      }
    }

    final df = DateFormat('yyyy/MM/dd');
    final rangeLabel = _from == null || _to == null
        ? 'كل الفترات'
        : 'من ${df.format(_from!)} إلى ${df.format(_to!)}';

    final reports = [
      _ReportItem(
        'تقرير المبيعات الشامل',
        LucideIcons.trendingUp,
        AppColors.primary,
        'إجمالي المبيعات: ${totalSales.toStringAsFixed(2)} ج.م\n'
        'عدد الفواتير المصدرة: ${salesInvoices.length}\n'
        'متوسط قيمة الفاتورة: ${salesInvoices.isEmpty ? '0.00' : (totalSales / salesInvoices.length).toStringAsFixed(2)} ج.م\n'
        'نقدي: ${salesCash.toStringAsFixed(2)} | فيزا: ${salesCard.toStringAsFixed(2)} | فوري: ${salesFawry.toStringAsFixed(2)} | آجل: ${salesCredit.toStringAsFixed(2)} ج.م',
      ),
      _ReportItem(
        'تقرير المشتريات والموردين',
        LucideIcons.shoppingBag,
        AppColors.info,
        'إجمالي المشتريات: ${totalPurchases.toStringAsFixed(2)} ج.م\n'
        'عدد فواتير الشراء: ${purchaseInvoices.length}\n'
        'عدد الموردين المسجلين: ${suppliers.length}',
      ),
      _ReportItem(
        'تقرير الأرباح الفعلية',
        LucideIcons.dollarSign,
        AppColors.success,
        'إجمالي قيمة المبيعات: ${totalSalesOfItems.toStringAsFixed(2)} ج.م\n'
        'تكلفة البضاعة المباعة: ${totalCost.toStringAsFixed(2)} ج.م\n'
        'صافي الربح الفعلي: ${realProfit.toStringAsFixed(2)} ج.م',
      ),
      _ReportItem(
        'تقرير تقييم المخزون',
        LucideIcons.warehouse,
        AppColors.warning,
        'إجمالي الأصناف بالمخزن: ${products.length}\n'
        'إجمالي عدد القطع: ${products.fold<double>(0, (s, p) => s + p.currentQuantity).toInt()}\n'
        'القيمة الإجمالية بسعر الشراء: ${products.fold<double>(0, (s, p) => s + (p.currentQuantity * p.purchasePrice)).toStringAsFixed(2)} ج.م',
      ),
      _ReportItem(
        'تقرير نواقص المخزن',
        LucideIcons.alertTriangle,
        AppColors.error,
        'الأصناف التي وصلت للحد الأدنى: ${products.where((p) => p.currentQuantity <= (p.minQuantity > 0 ? p.minQuantity : 5)).length}\n'
        'الأصناف المنتهية (0 قطعة): ${products.where((p) => p.currentQuantity == 0).length}',
      ),
      _ReportItem(
        'تقرير الحركة المالية والخزنة',
        LucideIcons.wallet,
        AppColors.primaryLight,
        'إجمالي المقبوضات/الإيداعات: ${totalIncome.toStringAsFixed(2)} ج.م\n'
        'إجمالي المصروفات/السحوبات: ${totalExpense.toStringAsFixed(2)} ج.م\n'
        'صافي الحركة: ${(totalIncome - totalExpense).toStringAsFixed(2)} ج.م\n'
        'مقبوضات (نقدي/فيزا/فوري): ${inCash.toStringAsFixed(2)} / ${inCard.toStringAsFixed(2)} / ${inFawry.toStringAsFixed(2)} ج.م\n'
        'مصروفات (نقدي/فيزا/فوري): ${outCash.toStringAsFixed(2)} / ${outCard.toStringAsFixed(2)} / ${outFawry.toStringAsFixed(2)} ج.م',
      ),
      _ReportItem(
        'تقرير حسابات العملاء',
        LucideIcons.users,
        AppColors.info,
        'إجمالي عدد العملاء: ${customers.length}\n'
        'إجمالي مديونيات العملاء الآجلة: ${customers.fold<double>(0, (s, c) => s + c.balance).toStringAsFixed(2)} ج.م',
      ),
      _ReportItem(
        'تقرير حسابات الموردين',
        LucideIcons.truck,
        AppColors.warning,
        'إجمالي عدد الموردين: ${suppliers.length}\n'
        'إجمالي مستحقات الموردين: ${suppliers.fold<double>(0, (s, sup) => s + sup.balance).toStringAsFixed(2)} ج.م',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'التقارير التحليلية والإحصاءات',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: Icon(LucideIcons.calendar, size: 16),
                  label: Text(rangeLabel, style: TextStyle(fontFamily: 'Cairo')),
                ),
                if (_from != null) ...[
                  SizedBox(width: 8.w),
                  IconButton(
                    onPressed: () => setState(() {
                      _from = null;
                      _to = null;
                    }),
                    icon: Icon(LucideIcons.x, size: 16),
                    tooltip: 'مسح الفترة',
                  ),
                ],
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'استعراض وقراءة كشوفات وتقارير المبيعات، المخزون، والأرباح مباشرة من قاعدة البيانات',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.2,
                ),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final r = reports[index];
                  return InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (c) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: AlertDialog(
                            title: Row(
                              children: [
                                Icon(r.icon, color: r.color),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    r.title,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            content: SizedBox(
                              width: 450.w,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الفترة: $rangeLabel',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    r.details,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 14.sp,
                                      height: 1.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                onPressed: () => Navigator.pop(c),
                                child: Text(
                                  'إغلاق',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: r.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(r.icon, color: r.color, size: 24),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    fontSize: 14.sp,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'انقر لعرض تفاصيل التقرير الحي',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronLeft,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportItem {
  final String title;
  final IconData icon;
  final Color color;
  final String details;
  const _ReportItem(this.title, this.icon, this.color, this.details);
}
