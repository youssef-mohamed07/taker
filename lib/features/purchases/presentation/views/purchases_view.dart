import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';

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
                        'إدارة المشتريات',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'متابعة وتجهيز فواتير الشراء وحسابات الموردين',
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
                  onPressed: () => _showNewPurchaseDialog(context, db),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text(
                    'فاتورة شراء جديدة',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'المبلغ المدفوع',
                    totalPaid.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.checkCircle2,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
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
            const SizedBox(height: 24),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'ابحث برقم الفاتورة أو اسم المورد...',
                  prefixIcon: Icon(LucideIcons.search, color: AppColors.textSecondary, size: 20),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Table of Purchases
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.fileX, size: 48, color: AppColors.textTertiary),
                            SizedBox(height: 12),
                            Text(
                              'لا توجد فواتير شراء متطابقة',
                              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final sName = supplierMap[p.supplierId] ?? 'مورد غير معروف';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.fileText, color: AppColors.primary, size: 20),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'فاتورة #${p.invoiceNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: p.remaining <= 0 ? AppColors.successLight : AppColors.warningLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p.remaining <= 0 ? 'مكفولة / مدفوعة' : 'آجل / متبقي',
                                    style: TextStyle(
                                      color: p.remaining <= 0 ? AppColors.success : AppColors.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'المورد: $sName | التاريخ: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(p.createdAt)}',
                              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${p.total.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'المدفوع: ${p.paid.toStringAsFixed(2)} | المتبقي: ${p.remaining.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo'),
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

  Widget _buildMetricCard(
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

  void _showNewPurchaseDialog(BuildContext context, AppDatabase db) {
    int? selectedSupplierId;
    final List<PurchaseCartItem> cartItems = [];
    final paidController = TextEditingController(text: '0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final suppliersAsync = ref.read(suppliersStreamProvider);
            final productsAsync = ref.read(productsStreamProvider);

            final suppliers = suppliersAsync.value ?? [];
            final products = productsAsync.value ?? [];

            final subtotal = cartItems.fold<double>(0, (sum, i) => sum + i.total);
            final paid = double.tryParse(paidController.text) ?? 0;
            final remaining = subtotal - paid;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Row(
                  children: [
                    Icon(LucideIcons.shoppingBag, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('فاتورة شراء جديدة من مورد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SizedBox(
                  width: 700,
                  height: 500,
                  child: Column(
                    children: [
                      // Supplier selection
                      Row(
                        children: [
                          const Text('اختر المورد:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedSupplierId,
                              hint: const Text('حدد المورد', style: TextStyle(fontFamily: 'Cairo')),
                              items: suppliers.map((s) {
                                return DropdownMenuItem<int>(
                                  value: s.id,
                                  child: Text(s.name, style: const TextStyle(fontFamily: 'Cairo')),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() => selectedSupplierId = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Add Item controls
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<Product>(
                              hint: const Text('اختر المنتج للإضافة للمشتريات', style: TextStyle(fontFamily: 'Cairo')),
                              items: products.map((p) {
                                return DropdownMenuItem<Product>(
                                  value: p,
                                  child: Text('${p.nameAr} (سعر الشراء الحالي: ${p.purchasePrice})', style: const TextStyle(fontFamily: 'Cairo')),
                                );
                              }).toList(),
                              onChanged: (p) {
                                if (p != null) {
                                  final existingIdx = cartItems.indexWhere((item) => item.product.id == p.id);
                                  if (existingIdx >= 0) {
                                    final existing = cartItems[existingIdx];
                                    cartItems[existingIdx] = PurchaseCartItem(
                                      product: p,
                                      quantity: existing.quantity + 1,
                                      purchasePrice: existing.purchasePrice,
                                    );
                                  } else {
                                    cartItems.add(PurchaseCartItem(
                                      product: p,
                                      quantity: 1,
                                      purchasePrice: p.purchasePrice > 0 ? p.purchasePrice : 10,
                                    ));
                                  }
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cart Items Table
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: cartItems.isEmpty
                              ? const Center(
                                  child: Text(
                                    'قم باختيار منتجات لإضافتها إلى فاتورة الشراء',
                                    style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Cairo'),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: cartItems.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = cartItems[index];
                                    return ListTile(
                                      title: Text(item.product.nameAr, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                      subtitle: Row(
                                        children: [
                                          const Text('الكمية: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                                            onPressed: () {
                                              if (item.quantity > 1) {
                                                cartItems[index] = PurchaseCartItem(
                                                  product: item.product,
                                                  quantity: item.quantity - 1,
                                                  purchasePrice: item.purchasePrice,
                                                );
                                              } else {
                                                cartItems.removeAt(index);
                                              }
                                              setDialogState(() {});
                                            },
                                          ),
                                          Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 18),
                                            onPressed: () {
                                              cartItems[index] = PurchaseCartItem(
                                                product: item.product,
                                                quantity: item.quantity + 1,
                                                purchasePrice: item.purchasePrice,
                                              );
                                              setDialogState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'الإجمالي: ${item.total.toStringAsFixed(2)} ج.م',
                                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                                            onPressed: () {
                                              cartItems.removeAt(index);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Totals & Paid Amount
                      Row(
                        children: [
                          Text('الإجمالي: ${subtotal.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          const Text('المدفوع: ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: paidController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                suffixText: 'ج.م',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text('المتبقي: ${remaining.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.error)),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: (selectedSupplierId == null || cartItems.isEmpty)
                        ? null
                        : () async {
                            final invoiceId = await DbHelpers.savePurchaseInvoice(
                              db,
                              supplierId: selectedSupplierId!,
                              items: cartItems,
                              subtotal: subtotal,
                              discount: 0.0,
                              total: subtotal,
                              paid: paid,
                              paymentMethod: 'cash',
                              userId: 1,
                            );
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم حفظ فاتورة الشراء رقم $invoiceId بنجاح وتحديث المخزون!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                    child: const Text('حفظ الفاتورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
