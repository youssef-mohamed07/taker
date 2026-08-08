import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/di/providers.dart';

class InventoryCountView extends ConsumerStatefulWidget {
  const InventoryCountView({super.key});

  @override
  ConsumerState<InventoryCountView> createState() => _InventoryCountViewState();
}

class _InventoryCountViewState extends ConsumerState<InventoryCountView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'جرد المخزون (تسوية الأرصدة)',
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _startNewCount(context),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('جرد جديد', style: TextStyle(fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: _CountsList(),
            ),
          ],
        ),
      ),
    );
  }
  
  void _startNewCount(BuildContext context) {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => const NewInventoryCountDialog(),
    ).then((_) {
      // ignore: invalid_use_of_protected_member
      setState(() {});
    });
  }
}

class _CountsList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CountsList> createState() => _CountsListState();
}

class _CountsListState extends ConsumerState<_CountsList> {
  List<InventoryCount> _counts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final db = ref.read(databaseProvider);
    final counts = await (db.select(db.inventoryCounts)..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])).get();
    setState(() {
      _counts = counts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_counts.isEmpty) return const Center(child: Text('لا توجد جلسات جرد سابقة', style: TextStyle(fontFamily: 'Cairo')));
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        itemCount: _counts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final count = _counts[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: count.status == 'completed' ? AppColors.successLight : AppColors.warningLight,
              child: Icon(
                count.status == 'completed' ? LucideIcons.checkCircle : LucideIcons.loader,
                color: count.status == 'completed' ? AppColors.success : AppColors.warning,
              ),
            ),
            title: Text(count.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            subtitle: Text('النوع: ${count.type == 'FULL' ? 'شامل' : 'جزئي'} | التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(count.createdAt)}', style: const TextStyle(fontFamily: 'Cairo')),
            trailing: count.status == 'completed' 
              ? const Text('تمت التسوية', style: TextStyle(color: AppColors.success, fontFamily: 'Cairo', fontWeight: FontWeight.bold))
              : const Text('قيد الانتظار', style: TextStyle(color: AppColors.warning, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }
}

class NewInventoryCountDialog extends ConsumerStatefulWidget {
  const NewInventoryCountDialog({super.key});

  @override
  ConsumerState<NewInventoryCountDialog> createState() => _NewInventoryCountDialogState();
}

class _NewInventoryCountDialogState extends ConsumerState<NewInventoryCountDialog> {
  final _nameController = TextEditingController();
  String _type = 'FULL';
  bool _isLoading = false;
  List<Product> _allProducts = [];
  Map<int, double> _actualQuantities = {};

  @override
  void initState() {
    super.initState();
    _nameController.text = 'جرد ${DateFormat('yyyy/MM/dd').format(DateTime.now())}';
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db = ref.read(databaseProvider);
    final prods = await db.select(db.products).get();
    setState(() {
      _allProducts = prods;
      for (final p in prods) {
        _actualQuantities[p.id] = p.currentQuantity;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 800.w,
        height: 600.h,
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('جلسة جرد جديدة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'اسم الجرد', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'FULL', child: Text('جرد شامل', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _type = val);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            const Text('المنتجات (أدخل الرصيد الفعلي في الحقل):', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            SizedBox(height: 8.h),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8.r)),
                child: _allProducts.isEmpty 
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _allProducts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = _allProducts[index];
                        return ListTile(
                          title: Text(product.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                          subtitle: Text('الرصيد الدفتري (بالنظام): ${product.currentQuantity}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                          trailing: SizedBox(
                            width: 150.w,
                            child: TextFormField(
                              initialValue: product.currentQuantity.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الرصيد الفعلي',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val) ?? 0.0;
                                _actualQuantities[product.id] = parsed;
                              },
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _isLoading ? null : _saveCount,
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ واعتماد التسوية', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _saveCount() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      
      await db.transaction(() async {
        final countId = await db.into(db.inventoryCounts).insert(
          InventoryCountsCompanion.insert(
            name: _nameController.text,
            type: _type,
            status: const drift.Value('completed'),
            userId: 1,
            completedAt: drift.Value(DateTime.now()),
          )
        );

        for (final product in _allProducts) {
          final actual = _actualQuantities[product.id] ?? 0.0;
          final system = product.currentQuantity;
          final diff = actual - system;
          
          if (diff != 0) {
            await db.into(db.inventoryCountItems).insert(
              InventoryCountItemsCompanion.insert(
                inventoryCountId: countId,
                productId: product.id,
                systemQuantity: system,
                actualQuantity: drift.Value(actual),
                difference: drift.Value(diff),
              )
            );
            
            await (db.update(db.products)..where((t) => t.id.equals(product.id)))
                .write(ProductsCompanion(currentQuantity: drift.Value(actual)));
                
            await db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: product.id,
                movementType: 'ADJUSTMENT',
                quantity: diff.abs(),
                referenceType: const drift.Value('inventory_count'),
                referenceId: drift.Value(countId),
                userId: 1,
                notes: drift.Value(diff > 0 ? 'فائض جرد' : 'عجز جرد'),
              )
            );
          }
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الجرد وتسوية الأرصدة بنجاح')));
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
}
