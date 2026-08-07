import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';

class ReportsView extends ConsumerWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesInvoices = ref.watch(salesInvoicesStreamProvider).value ?? [];
    final purchaseInvoices = ref.watch(purchaseInvoicesStreamProvider).value ?? [];
    final products = ref.watch(productsStreamProvider).value ?? [];
    final treasuryTx = ref.watch(treasuryTransactionsStreamProvider).value ?? [];
    final customers = ref.watch(customersStreamProvider).value ?? [];
    final suppliers = ref.watch(suppliersStreamProvider).value ?? [];

    final reports = [
      _ReportItem(
        'تقرير المبيعات الشامل',
        LucideIcons.trendingUp,
        AppColors.primary,
        'إجمالي المبيعات: ${salesInvoices.fold<double>(0, (s, i) => s + i.total).toStringAsFixed(2)} ج.م\n'
        'عدد الفواتير المصدرة: ${salesInvoices.length}\n'
        'متوسط قيمة الفاتورة: ${salesInvoices.isEmpty ? 0 : (salesInvoices.fold<double>(0, (s, i) => s + i.total) / salesInvoices.length).toStringAsFixed(2)} ج.م',
      ),
      _ReportItem(
        'تقرير المشتريات والموردين',
        LucideIcons.shoppingBag,
        AppColors.info,
        'إجمالي المشتريات: ${purchaseInvoices.fold<double>(0, (s, p) => s + p.total).toStringAsFixed(2)} ج.م\n'
        'عدد فواتير الشراء: ${purchaseInvoices.length}\n'
        'عدد الموردين المسجلين: ${suppliers.length}',
      ),
      _ReportItem(
        'تقرير الأرباح التقديرية',
        LucideIcons.dollarSign,
        AppColors.success,
        'إجمالي قيمة المبيعات: ${salesInvoices.fold<double>(0, (s, i) => s + i.total).toStringAsFixed(2)} ج.م\n'
        'تكلفة البضاعة المباعة التقديرية (70%): ${(salesInvoices.fold<double>(0, (s, i) => s + i.total) * 0.7).toStringAsFixed(2)} ج.م\n'
        'صافي الربح التقديري: ${(salesInvoices.fold<double>(0, (s, i) => s + i.total) * 0.3).toStringAsFixed(2)} ج.م',
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
        'إجمالي المقبوضات/الإيداعات: ${treasuryTx.where((t) => t.type == 'income' || t.type == 'sale').fold<double>(0, (s, t) => s + t.amount).toStringAsFixed(2)} ج.م\n'
        'إجمالي المصروفات/السحوبات: ${treasuryTx.where((t) => t.type == 'expense' || t.type == 'purchase').fold<double>(0, (s, t) => s + t.amount).toStringAsFixed(2)} ج.م',
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التقارير التحليلية والإحصاءات',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'استعراض وقراءة كشوفات وتقارير المبيعات، المخزون، والأرباح مباشرة من قاعدة البيانات',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 24),
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
                                const SizedBox(width: 8),
                                Text(r.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: SizedBox(
                              width: 450,
                              child: Text(
                                r.details,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.8),
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                onPressed: () => Navigator.pop(c),
                                child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: r.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(r.icon, color: r.color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'انقر لعرض تفاصيل التقرير الحي',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
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
