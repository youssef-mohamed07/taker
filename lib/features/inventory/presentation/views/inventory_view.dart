import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';

class InventoryView extends ConsumerStatefulWidget {
  const InventoryView({super.key});

  @override
  ConsumerState<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends ConsumerState<InventoryView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final db = ref.watch(databaseProvider);

    final products = productsAsync.value ?? [];
    final query = _searchController.text.trim().toLowerCase();
    final filtered = products.where((p) {
      final code = (p.internalCode ?? '').toLowerCase();
      return query.isEmpty ||
          p.nameAr.toLowerCase().contains(query) ||
          code.contains(query);
    }).toList();

    final totalQuantity = products.fold<double>(0, (sum, p) => sum + p.currentQuantity);
    final totalValue = products.fold<double>(0, (sum, p) => sum + (p.currentQuantity * p.purchasePrice));
    final lowStockItems = products.where((p) => p.currentQuantity <= (p.minQuantity > 0 ? p.minQuantity : 5)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
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
                        'إدارة المخزن والجرد',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'متابعة حركات الأصناف، كميات المخزون، وأذون الإضافة والصرف',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showStockAdjustDialog(context, db, isAddition: true),
                  icon: const Icon(LucideIcons.packagePlus, size: 18),
                  label: const Text('إذن إضافة رصيد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showStockAdjustDialog(context, db, isAddition: false),
                  icon: const Icon(LucideIcons.packageMinus, size: 18),
                  label: const Text('إذن صرف رصيد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top KPI Row
            Row(
              children: [
                Expanded(
                  child: _buildInventoryMetric(
                    'إجمالي قطع المخزون',
                    totalQuantity.toStringAsFixed(0),
                    'قطعة',
                    LucideIcons.boxes,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInventoryMetric(
                    'قيمة المخزون بسعر الشراء',
                    totalValue.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.dollarSign,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInventoryMetric(
                    'أصناف النواقص',
                    '${lowStockItems.length}',
                    'صنف',
                    LucideIcons.alertTriangle,
                    lowStockItems.isNotEmpty ? AppColors.error : AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن صنف بالمخزن بالاسم، الكود SKU، أو الباركوم...',
                  prefixIcon: Icon(LucideIcons.search, color: AppColors.textSecondary, size: 20),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Product Inventory Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('لا توجد منتجات بالمخزن', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textTertiary)),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isLow = item.currentQuantity <= (item.minQuantity > 0 ? item.minQuantity : 5);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isLow ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isLow ? LucideIcons.alertCircle : LucideIcons.box,
                                color: isLow ? AppColors.error : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  item.nameAr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isLow ? AppColors.errorLight : AppColors.successLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isLow ? 'مخزون منخفض' : 'متوفر',
                                    style: TextStyle(
                                      color: isLow ? AppColors.error : AppColors.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'كود: ${item.internalCode ?? '---'} | الحد الأدنى: ${item.minQuantity}',
                              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.currentQuantity} قطعة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isLow ? AppColors.error : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'سعر الشراء: ${item.purchasePrice} ج.م',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(LucideIcons.plusCircle, color: AppColors.success, size: 22),
                                  tooltip: 'إضافة كمية للمخزون',
                                  onPressed: () async {
                                    await DbHelpers.updateProductStock(db: db, productId: item.id, quantityDelta: 1);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('تم إضافة قطعة إلى مخزون ${item.nameAr}'), backgroundColor: AppColors.success),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.minusCircle, color: AppColors.error, size: 22),
                                  tooltip: 'خصم كمية من المخزون',
                                  onPressed: () async {
                                    if (item.currentQuantity > 0) {
                                      await DbHelpers.updateProductStock(db: db, productId: item.id, quantityDelta: -1);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('تم خصم قطعة من مخزون ${item.nameAr}'), backgroundColor: AppColors.warning),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
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

  Widget _buildInventoryMetric(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStockAdjustDialog(BuildContext context, AppDatabase db, {required bool isAddition}) {
    Product? selectedProduct;
    final qtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final productsAsync = ref.read(productsStreamProvider);
        final products = productsAsync.value ?? [];

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  isAddition ? LucideIcons.packagePlus : LucideIcons.packageMinus,
                  color: isAddition ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  isAddition ? 'إذن إضافة رصيد جديد للمخزن' : 'إذن صرف رصيد من المخزن',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Product>(
                      hint: const Text('حدد المنتج المراد تعديل رصيده', style: TextStyle(fontFamily: 'Cairo')),
                      isExpanded: true,
                      items: products.map((p) {
                        return DropdownMenuItem<Product>(
                          value: p,
                          child: Text(
                            '${p.nameAr} (الرصيد الحالي: ${p.currentQuantity})',
                            style: const TextStyle(fontFamily: 'Cairo'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (p) => selectedProduct = p,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAddition ? 'الكمية المضافة' : 'الكمية المنصرفة',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isAddition ? AppColors.success : AppColors.error),
                onPressed: () async {
                  if (selectedProduct != null) {
                    final qty = (double.tryParse(qtyController.text) ?? 1.0);
                    final delta = isAddition ? qty : -qty;
                    await DbHelpers.updateProductStock(db: db, productId: selectedProduct!.id, quantityDelta: delta);
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم تعديل رصيد ${selectedProduct!.nameAr} بنجاح!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ الإذن', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
