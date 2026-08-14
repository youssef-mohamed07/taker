import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  bool _showOnlyLowStock = false;

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
      final matchesSearch = query.isEmpty || p.nameAr.toLowerCase().contains(query) || code.contains(query);
      if (!matchesSearch) return false;
      
      if (_showOnlyLowStock) {
        return p.currentQuantity <= (p.minQuantity > 0 ? p.minQuantity : 5);
      }
      return true;
    }).toList();

    final totalQuantity = products.fold<double>(0, (sum, p) => sum + p.currentQuantity);
    final totalValue = products.fold<double>(0, (sum, p) => sum + (p.currentQuantity * p.purchasePrice));
    final lowStockItems = products.where((p) => p.currentQuantity <= (p.minQuantity > 0 ? p.minQuantity : 5)).toList();

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
                        'إدارة المخزن والجرد',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'متابعة حركات الأصناف، كميات المخزون، وأذون الإضافة والصرف',
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
                  onPressed: () => _showStockAdjustDialog(context, db, isAddition: true),
                  icon: Icon(LucideIcons.packagePlus, size: 18),
                  label: Text('إذن إضافة رصيد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton.icon(
                  onPressed: () => _showStockAdjustDialog(context, db, isAddition: false),
                  icon: Icon(LucideIcons.packageMinus, size: 18),
                  label: Text('إذن صرف رصيد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildInventoryMetric(
                    'قيمة المخزون بسعر الشراء',
                    totalValue.toStringAsFixed(2),
                    'ج.م',
                    LucideIcons.dollarSign,
                    AppColors.success,
                  ),
                ),
                SizedBox(width: 16.w),
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
            SizedBox(height: 24.h),

            // Search bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن صنف بالمخزن بالاسم، الكود SKU، أو الباركوم...',
                        prefixIcon: Icon(LucideIcons.search, color: AppColors.textSecondary, size: 20),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showOnlyLowStock = !_showOnlyLowStock;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: _showOnlyLowStock ? AppColors.error : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: _showOnlyLowStock ? AppColors.error : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          color: _showOnlyLowStock ? Colors.white : AppColors.error,
                          size: 20,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'تصفية النواقص',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: _showOnlyLowStock ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Product Inventory Table
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
                        child: Text('لا توجد منتجات بالمخزن', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textTertiary)),
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
                              fontSize: 13.sp,
                            ),
                            columnSpacing: 32.w,
                            horizontalMargin: 24.w,
                            dividerThickness: 1.h,
                            showBottomBorder: true,
                            columns: const [
                              DataColumn(label: Text('الصنف')),
                              DataColumn(label: Text('الكود / SKU')),
                              DataColumn(label: Text('الحد الأدنى')),
                              DataColumn(label: Text('الرصيد الحالي')),
                              DataColumn(label: Text('قيمة الرصيد (شراء)')),
                              DataColumn(label: Text('حالة المخزون')),
                              DataColumn(label: Text('تسويات المخزون (إضافة/خصم)')),
                            ],
                            rows: filtered.map((item) {
                              final isLow = item.currentQuantity <= (item.minQuantity > 0 ? item.minQuantity : 5);
                              final inventoryValue = item.currentQuantity * item.purchasePrice;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isLow ? LucideIcons.alertCircle : LucideIcons.box, size: 16, color: isLow ? AppColors.error : AppColors.primary),
                                        SizedBox(width: 8.w),
                                        Text(item.nameAr, style: TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.internalCode?.isNotEmpty == true ? item.internalCode! : '---',
                                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(Text('${item.minQuantity} قطعة', style: TextStyle(color: AppColors.textSecondary))),
                                  DataCell(
                                    Text(
                                      '${item.currentQuantity} قطعة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15.sp,
                                        color: isLow ? AppColors.error : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${inventoryValue.toStringAsFixed(2)} ج.م', style: TextStyle(color: AppColors.textSecondary))),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: isLow ? AppColors.errorLight : AppColors.successLight,
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        isLow ? 'مخزون منخفض' : 'متوفر',
                                        style: TextStyle(
                                          color: isLow ? AppColors.error : AppColors.success,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(LucideIcons.plusCircle, color: AppColors.success, size: 20),
                                          tooltip: 'إضافة قطعة',
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
                                          icon: Icon(LucideIcons.minusCircle, color: AppColors.error, size: 20),
                                          tooltip: 'خصم قطعة',
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


  // ignore: unused_element
  void _showRecordDamageDialog(Product product) {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('تسجيل هالك/تالف: ${product.nameAr}', style: const TextStyle(fontFamily: 'Cairo')),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'الرصيد الحالي: ${product.currentQuantity} قطعة',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية التالفة',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'مطلوب';
                        final num = double.tryParse(val);
                        if (num == null || num <= 0) return 'قيمة غير صالحة';
                        if (num > product.currentQuantity) return 'الكمية تتجاوز الرصيد';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'سبب التلف (مثال: منتهي الصلاحية، مكسور)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'يرجى كتابة السبب' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);
                          try {
                            final db = ref.read(databaseProvider);
                            final qty = double.parse(qtyController.text);
                            
                            await db.transaction(() async {
                              // 1. Reduce stock
                              final newQty = product.currentQuantity - qty;
                              await (db.update(db.products)..where((t) => t.id.equals(product.id)))
                                  .write(ProductsCompanion(currentQuantity: drift.Value(newQty)));
                                  
                              // 2. Record movement as DAMAGED
                              await db.into(db.stockMovements).insert(
                                StockMovementsCompanion.insert(
                                  productId: product.id,
                                  movementType: 'DAMAGED',
                                  quantity: qty,
                                  userId: 1, // Currently hardcoded user 1
                                  notes: drift.Value('هالك/تالف: ${reasonController.text}'),
                                )
                              );
                            });

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم تسجيل الهالك وخصمه من المخزون بنجاح.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              // Using setState to trigger UI update for the stream provider isn't strictly necessary 
                              // if it's watched, but calling setState empty ensures the table redraws if not fully reactive
                              setState(() {}); 
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e')),
                              );
                            }
                          } finally {
                            setDialogState(() => isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تأكيد خصم التالف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
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
                SizedBox(width: 8.w),
                Text(
                  isAddition ? 'إذن إضافة رصيد جديد للمخزن' : 'إذن صرف رصيد من المخزن',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 500.w,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Product>(
                      hint: Text('حدد المنتج المراد تعديل رصيده', style: TextStyle(fontFamily: 'Cairo')),
                      isExpanded: true,
                      items: products.map((p) {
                        return DropdownMenuItem<Product>(
                          value: p,
                          child: Text(
                            '${p.nameAr} (الرصيد الحالي: ${p.currentQuantity})',
                            style: TextStyle(fontFamily: 'Cairo'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (p) => selectedProduct = p,
                    ),
                    SizedBox(height: 16.h),
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
                child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
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
                child: Text('حفظ الإذن', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
