import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';

import 'new_purchase_invoice_dialog.dart';
class PurchasesView extends ConsumerStatefulWidget {
  const PurchasesView({super.key});

  @override
  ConsumerState<PurchasesView> createState() => _PurchasesViewState();
}

class _PurchasesViewState extends ConsumerState<PurchasesView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchaseInvoicesStreamProvider);
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final db = ref.watch(databaseProvider);

    final purchases = purchasesAsync.value ?? [];
    final suppliers = suppliersAsync.value ?? [];
    final supplierMap = {for (var s in suppliers) s.id: s.name};

    // Filter purchases
    final query = _searchController.text.trim().toLowerCase();
    final filtered = purchases.where((p) {
      final sName = (supplierMap[p.supplierId] ?? '').toLowerCase();
      final num = p.invoiceNumber.toLowerCase();
      return query.isEmpty || sName.contains(query) || num.contains(query);
    }).toList();

    final totalPurchases = purchases.fold<double>(0, (sum, p) => sum + p.total);
    final totalPaid = purchases.fold<double>(0, (sum, p) => sum + p.paid);
    final totalRemaining = purchases.fold<double>(0, (sum, p) => sum + p.remaining);

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
                        'إدارة المشتريات',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'متابعة وتجهيز فواتير الشراء وحسابات الموردين',
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
                  onPressed: () => _showNewPurchaseDialog(context, db),
                  icon: Icon(LucideIcons.plus, size: 18),
                  label: Text(
                    'فاتورة شراء جديدة',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
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

            // Metrics Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'إجمالي المشتريات',
                    totalPurchases.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.shoppingBag,
                    AppColors.primary,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildMetricCard(
                    'المبلغ المدفوع',
                    totalPaid.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.checkCircle2,
                    AppColors.success,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildMetricCard(
                    'المتبقي / المديونية',
                    totalRemaining.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.alertCircle,
                    totalRemaining > 0 ? AppColors.error : AppColors.info,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Search Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الفاتورة أو اسم المورد...',
                  prefixIcon: Icon(LucideIcons.search, color: AppColors.textSecondary, size: 20),
                  border: InputBorder.none,
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Table of Purchases
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.fileX, size: 48, color: AppColors.textTertiary),
                            SizedBox(height: 12.h),
                            Text(
                              'لا توجد فواتير شراء متطابقة',
                              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'),
                            ),
                          ],
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
                              DataColumn(label: Text('رقم الفاتورة')),
                              DataColumn(label: Text('المورد')),
                              DataColumn(label: Text('التاريخ')),
                              DataColumn(label: Text('الإجمالي / المدفوع / المتبقي')),
                              DataColumn(label: Text('الحالة')),
                            ],
                            rows: filtered.map((p) {
                              final sName = supplierMap[p.supplierId] ?? 'مورد غير معروف';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8.w),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Icon(LucideIcons.fileText, color: AppColors.primary, size: 16),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text('فاتورة #${p.invoiceNumber}', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(sName, style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(intl.DateFormat('yyyy/MM/dd HH:mm').format(p.createdAt), style: TextStyle(color: AppColors.textSecondary))),
                                  DataCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${p.total.toStringAsFixed(2)} ج.م', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text(
                                          'المدفوع: ${p.paid.toStringAsFixed(2)} | المتبقي: ${p.remaining.toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: p.remaining <= 0 ? AppColors.successLight : AppColors.warningLight,
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        p.remaining <= 0 ? 'مكفولة / مدفوعة' : 'آجل / متبقي',
                                        style: TextStyle(
                                          color: p.remaining <= 0 ? AppColors.success : AppColors.warning,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
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

  Widget _buildMetricCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Cairo'),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    unit,
                    style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNewPurchaseDialog(BuildContext context, AppDatabase db) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NewPurchaseInvoiceDialog(),
    );
  }
}
