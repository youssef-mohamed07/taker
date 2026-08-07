import 'package:flutter/material.dart';
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لوحة التحكم',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'مرحباً بك في نظام تاجر لإدارة تجارة الجملة والقطاعي',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                _buildQuickAction(
                  context,
                  LucideIcons.monitor,
                  'نقطة البيع',
                  AppColors.primary,
                  () => context.push('/pos'),
                ),
                const SizedBox(width: 8),
                _buildQuickAction(
                  context,
                  LucideIcons.plus,
                  'منتج جديد',
                  AppColors.success,
                  () => context.push('/products/add'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // KPI Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'مبيعات اليوم',
                    todaySales.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.trendingUp,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    'مبيعات الشهر',
                    monthSales.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.calendar,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    'الأرباح التقديرية',
                    totalProfits.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.dollarSign,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    'قيمة المخزون',
                    inventoryValue.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.warehouse,
                    AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'المنتجات',
                    '${products.length}',
                    LucideIcons.box,
                    AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'الفواتير',
                    '${invoices.length}',
                    LucideIcons.receipt,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'العملاء',
                    '${customers.length}',
                    LucideIcons.users,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'الموردون',
                    '${suppliers.length}',
                    LucideIcons.truck,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'نواقص المخزن',
                    '${lowStockProducts.length}',
                    LucideIcons.alertTriangle,
                    lowStockProducts.isEmpty ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Charts & Alerts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sales chart
                Expanded(
                  flex: 2,
                  child: _buildSalesChartCard('مبيعات آخر 7 أيام', last7DaysSales),
                ),
                const SizedBox(width: 16),
                // Alerts
                Expanded(child: _buildAlertsCard(lowStockProducts)),
              ],
            ),
            const SizedBox(height: 24),

            // Recent invoices & best products
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildRecentInvoicesCard(
                    'آخر الفواتير',
                    LucideIcons.receipt,
                    invoices.take(5).toList(),
                    customersList,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTopProductsCard(
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
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'مباشر',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Cairo',
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

  Widget _buildSalesChartCard(String title, Map<String, double> salesData) {
    final maxSale = salesData.values.isEmpty
        ? 100.0
        : (salesData.values.reduce((a, b) => a > b ? a : b) == 0 ? 100.0 : salesData.values.reduce((a, b) => a > b ? a : b));

    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.barChart2, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 32,
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
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
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

  Widget _buildAlertsCard(List<Product> lowStockProducts) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.bell, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text(
                'تنبيهات النظام',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: lowStockProducts.isEmpty ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${lowStockProducts.length}',
                  style: TextStyle(
                    color: lowStockProducts.isEmpty ? AppColors.success : AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: lowStockProducts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.checkCircle,
                          size: 40,
                          color: AppColors.success,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'لا توجد تنبيهات - المخزون ممتاز',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: lowStockProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = lowStockProducts[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(LucideIcons.alertOctagon, color: AppColors.error, size: 18),
                        title: Text(
                          item.nameAr,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'المتبقي: ${item.currentQuantity} قطعة (الحد الأدنى: ${item.minQuantity})',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary,
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

  Widget _buildRecentInvoicesCard(
    String title,
    IconData icon,
    List<Invoice> recentInvoices,
    List<Customer> customers,
  ) {
    final customerMap = {for (var c in customers) c.id: c.name};

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: recentInvoices.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد فواتير بعد',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: recentInvoices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final inv = recentInvoices[index];
                      final custName = customerMap[inv.customerId] ?? 'عميل نقدي';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '#${inv.invoiceNumber} - $custName',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          intl.DateFormat('yyyy/MM/dd HH:mm').format(inv.createdAt),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Text(
                          '${inv.total.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
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

  Widget _buildTopProductsCard(
    String title,
    IconData icon,
    List<Product> topProducts,
  ) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: topProducts.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد منتجات بعد',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: topProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
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
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          p.nameAr,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'المخزون الحالي: ${p.currentQuantity}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Text(
                          '${p.wholesalePrice} ج.م (جملة)',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
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
