import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesInvoicesAsync = ref.watch(salesInvoicesStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final customersList = customersAsync.value ?? [];

    final invoices = salesInvoicesAsync.value ?? [];
    final products = productsAsync.value ?? [];
    final customers = customersAsync.value ?? [];
    final suppliers = suppliersAsync.value ?? [];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    // Filtered Metrics
    final todayInvoices = invoices.where((i) => i.createdAt.isAfter(todayStart)).toList();
    final monthInvoices = invoices.where((i) => i.createdAt.isAfter(monthStart)).toList();

    final todaySales = todayInvoices.fold<double>(0, (sum, i) => sum + i.total);
    final monthSales = monthInvoices.fold<double>(0, (sum, i) => sum + i.total);

    // Estimated profit (total sales - estimated cost 70%)
    final totalProfits = monthInvoices.fold<double>(0, (sum, i) => sum + (i.total - i.subtotal * 0.7));

    // Inventory Value
    final inventoryValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.currentQuantity * p.purchasePrice),
    );

    // Low stock items
    final lowStockProducts = products.where((p) => p.currentQuantity <= (p.minQuantity > 0 ? p.minQuantity : 5)).toList();

    // Last 7 days sales breakdown
    final Map<String, double> last7DaysSales = {};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = intl.DateFormat('MM/dd').format(date);
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayTotal = invoices
          .where((inv) => inv.createdAt.isAfter(dayStart) && inv.createdAt.isBefore(dayEnd))
          .fold<double>(0, (sum, inv) => sum + inv.total);

      last7DaysSales[dateKey] = dayTotal;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
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
                        'لوحة التحكم',
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'مرحباً بك في نظام تاجر لإدارة تجارة الجملة والقطاعي',
                        style: TextStyle(
                          fontSize: 20.sp,
                          color: Colors.black87,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                _buildQuickAction(context,
                  LucideIcons.monitor,
                  'نقطة البيع',
                  AppColors.primary,
                  () => context.push('/pos'),
                ),
                SizedBox(width: 8.w),
                _buildQuickAction(context,
                  LucideIcons.plus,
                  'منتج جديد',
                  AppColors.success,
                  () => context.push('/products/add'),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // KPI Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(context, 
                    'مبيعات اليوم',
                    todaySales.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.trendingUp,
                    AppColors.primary,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildKpiCard(context, 
                    'مبيعات الشهر',
                    monthSales.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.calendar,
                    AppColors.info,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildKpiCard(context, 
                    'الأرباح التقديرية',
                    totalProfits.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.dollarSign,
                    AppColors.success,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildKpiCard(context, 
                    'قيمة المخزون',
                    inventoryValue.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.warehouse,
                    AppColors.warning,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Stats Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(context, 
                    'المنتجات',
                    '${products.length}',
                    LucideIcons.box,
                    AppColors.primaryLight,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStatCard(context, 
                    'الفواتير',
                    '${invoices.length}',
                    LucideIcons.receipt,
                    AppColors.success,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStatCard(context, 
                    'العملاء',
                    '${customers.length}',
                    LucideIcons.users,
                    AppColors.info,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStatCard(context, 
                    'الموردون',
                    '${suppliers.length}',
                    LucideIcons.truck,
                    AppColors.warning,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStatCard(context, 
                    'نواقص المخزن',
                    '${lowStockProducts.length}',
                    LucideIcons.alertTriangle,
                    lowStockProducts.isEmpty ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Charts & Alerts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sales chart
                Expanded(
                  flex: 2,
                  child: _buildSalesChartCard(context, 'مبيعات آخر 7 أيام', last7DaysSales),
                ),
                SizedBox(width: 16.w),
                // Alerts
                Expanded(child: _buildAlertsCard(context, lowStockProducts)),
              ],
            ),
            SizedBox(height: 24.h),

            // Recent invoices & best products
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildRecentInvoicesCard(context, 
                    'آخر الفواتير',
                    LucideIcons.receipt,
                    invoices.take(5).toList(),
                    customersList,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildTopProductsCard(context, 
                    'أفضل المنتجات بالمخزن',
                    LucideIcons.star,
                    products.take(5).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(label, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 20.sp)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, 
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'مباشر',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 20.sp,
              color: Colors.black,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.black87,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, 
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.black87,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChartCard(BuildContext context, String title, Map<String, double> salesData) {
    final maxSale = salesData.values.isEmpty
        ? 100.0
        : (salesData.values.reduce((a, b) => a > b ? a : b) == 0 ? 100.0 : salesData.values.reduce((a, b) => a > b ? a : b));

    return Container(
      height: 320.h,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart2, color: AppColors.primary, size: 24),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableBarHeight = (constraints.maxHeight - 54).clamp(10.0, constraints.maxHeight);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: salesData.entries.map((entry) {
                    final heightFactor = (entry.value / maxSale).clamp(0.05, 1.0);
                    final barHeight = availableBarHeight * heightFactor;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          entry.value > 0 ? entry.value.toStringAsFixed(0) : '0',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 32.w,
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.black,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context, List<Product> lowStockProducts) {
    return Container(
      height: 320.h,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.bell, size: 24, color: AppColors.warning),
              SizedBox(width: 8.w),
              Text(
                'تنبيهات النظام',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: lowStockProducts.isEmpty ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '${lowStockProducts.length}',
                  style: TextStyle(
                    color: lowStockProducts.isEmpty ? AppColors.success : AppColors.error,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: lowStockProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.checkCircle,
                          size: 40,
                          color: AppColors.success,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'لا توجد تنبيهات - المخزون ممتاز',
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: 'Cairo',
                            fontSize: 20.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: lowStockProducts.length,
                    separatorBuilder: (_, __) => Divider(height: 1.h),
                    itemBuilder: (context, index) {
                      final item = lowStockProducts[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(LucideIcons.alertOctagon, color: AppColors.error, size: 18),
                        title: Text(
                          item.nameAr,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 20.sp,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'المتبقي: ${item.currentQuantity} قطعة (الحد الأدنى: ${item.minQuantity})',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18.sp,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInvoicesCard(BuildContext context, 
    String title,
    IconData icon,
    List<Invoice> recentInvoices,
    List<Customer> customers,
  ) {
    final customerMap = {for (var c in customers) c.id: c.name};

    return Container(
      height: 280.h,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: recentInvoices.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد فواتير بعد',
                      style: TextStyle(
                        color: Colors.black54,
                        fontFamily: 'Cairo',
                        fontSize: 20.sp,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: recentInvoices.length,
                    separatorBuilder: (_, __) => Divider(height: 1.h),
                    itemBuilder: (context, index) {
                      final inv = recentInvoices[index];
                      final custName = customerMap[inv.customerId] ?? 'عميل نقدي';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '#${inv.invoiceNumber} - $custName',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 20.sp,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          intl.DateFormat('yyyy/MM/dd HH:mm').format(inv.createdAt),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18.sp,
                            color: Colors.black87,
                          ),
                        ),
                        trailing: Text(
                          '${inv.total.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 20.sp,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(BuildContext context, 
    String title,
    IconData icon,
    List<Product> topProducts,
  ) {
    return Container(
      height: 280.h,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: topProducts.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد منتجات بعد',
                      style: TextStyle(
                        color: Colors.black54,
                        fontFamily: 'Cairo',
                        fontSize: 20.sp,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: topProducts.length,
                    separatorBuilder: (_, __) => Divider(height: 1.h),
                    itemBuilder: (context, index) {
                      final p = topProducts[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          p.nameAr,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 20.sp,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'المخزون الحالي: ${p.currentQuantity}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18.sp,
                            color: Colors.black87,
                          ),
                        ),
                        trailing: Text(
                          '${p.wholesalePrice} ج.م (جملة)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            fontSize: 20.sp,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
