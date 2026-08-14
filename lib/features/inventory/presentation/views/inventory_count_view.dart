import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جرد المخزون وتكافؤ الأرصدة',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'تسوية الفروقات بين الرصيد الدفتري بالنظام والرصيد الفعلي للمخزن',
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
                  onPressed: () => _startNewCount(context),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text(
                    'بدء جلسة جرد جديدة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Expanded(child: _CountsList()),
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
      if (mounted) setState(() {});
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
    final counts = await (db.select(
      db.inventoryCounts,
    )..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])).get();
    if (mounted) {
      setState(() {
        _counts = counts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_counts.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.clipboardList,
                size: 48,
                color: AppColors.textTertiary,
              ),
              SizedBox(height: 12.h),
              Text(
                'لا توجد جلسات جرد سابقة حتى الآن',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 8.h,
            ),
            leading: CircleAvatar(
              backgroundColor: count.status == 'completed'
                  ? AppColors.successLight
                  : AppColors.warningLight,
              child: Icon(
                count.status == 'completed'
                    ? LucideIcons.checkCircle
                    : LucideIcons.loader,
                color: count.status == 'completed'
                    ? AppColors.success
                    : AppColors.warning,
                size: 20,
              ),
            ),
            title: Text(
              count.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                fontSize: 15.sp,
              ),
            ),
            subtitle: Text(
              'النوع: ${count.type == 'FULL' ? 'جرد شامل' : 'جرد جزئي'} | التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(count.createdAt)}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: count.status == 'completed'
                        ? AppColors.successLight
                        : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    count.status == 'completed'
                        ? 'تمت التسوية'
                        : 'قيد الانتظار',
                    style: TextStyle(
                      color: count.status == 'completed'
                          ? AppColors.success
                          : AppColors.warning,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                IconButton(
                  icon: const Icon(LucideIcons.eye, color: AppColors.primary),
                  onPressed: () => _showCountDetailsDialog(context, count),
                  tooltip: 'عرض تفاصيل الجرد',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCountDetailsDialog(
    BuildContext context,
    InventoryCount count,
  ) async {
    final db = ref.read(databaseProvider);
    final items = await (db.select(
      db.inventoryCountItems,
    )..where((t) => t.inventoryCountId.equals(count.id))).get();
    final products = await db.select(db.products).get();
    final prodMap = {for (var p in products) p.id: p.nameAr};

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        title: Text(
          'تفاصيل جلسه الجرد: ${count.name}',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 600.w,
          height: 400.h,
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'لم يتم تسجيل أية فروقات في هذا الجرد (جميع الأرصدة مطابقة)',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final prodName =
                        prodMap[item.productId] ?? 'منتج #${item.productId}';
                    final diff = item.difference ?? 0.0;
                    final isSurplus = diff > 0;

                    return ListTile(
                      title: Text(
                        prodName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'الرصيد الدفتري: ${item.systemQuantity} | الرصيد الفعلي: ${item.actualQuantity ?? item.systemQuantity}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: isSurplus
                              ? AppColors.successLight
                              : AppColors.errorLight,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isSurplus
                              ? 'فائض (+${diff.abs()})'
                              : 'عجز (-${diff.abs()})',
                          style: TextStyle(
                            color: isSurplus
                                ? AppColors.success
                                : AppColors.error,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

class NewInventoryCountDialog extends ConsumerStatefulWidget {
  const NewInventoryCountDialog({super.key});

  @override
  ConsumerState<NewInventoryCountDialog> createState() =>
      _NewInventoryCountDialogState();
}

class _NewInventoryCountDialogState
    extends ConsumerState<NewInventoryCountDialog> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  String _type = 'FULL';
  String _searchQuery = '';
  bool _isSaving = false;
  final Map<int, double> _actualQuantities = {};

  @override
  void initState() {
    super.initState();
    _nameController.text =
        'جرد ${DateFormat('yyyy/MM/dd').format(DateTime.now())}';
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final allProducts = productsAsync.value ?? [];

    // Initialize map with default system quantity for any new product
    for (final p in allProducts) {
      _actualQuantities.putIfAbsent(p.id, () => p.currentQuantity);
    }

    final filteredProducts = allProducts.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final name = p.nameAr.toLowerCase();
      final code = (p.internalCode ?? '').toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    int totalDiffCount = 0;
    double totalSurplus = 0;
    double totalDeficit = 0;

    for (final p in allProducts) {
      final actual = _actualQuantities[p.id] ?? p.currentQuantity;
      final diff = actual - p.currentQuantity;
      if (diff > 0) {
        totalDiffCount++;
        totalSurplus += diff;
      } else if (diff < 0) {
        totalDiffCount++;
        totalDeficit += diff.abs();
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 820.w, maxHeight: 620.h),
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.clipboardCheck,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'جلسة جرد وتسوية جديدة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(),
            SizedBox(height: 8.h),

            // Controls Row (Inputs)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم جلسة الجرد',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 12.h,
                      ),
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.sp,
                      ),
                    ),
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'نوع الجرد',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 12.h,
                      ),
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.sp,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'FULL',
                        child: Text(
                          'جرد شامل',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _type = val);
                    },
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم المنتج أو الكود...',
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 12.h,
                      ),
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.sp,
                      ),
                    ),
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Subtitle & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المنتجات (${filteredProducts.length} منتج) — أدخل الرصيد الفعلي الموجود حالياً بالمخزن:',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
                if (totalDiffCount > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'يوجد $totalDiffCount أصناف بها فروقات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.h),

            // Products Table List
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: productsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      'خطأ في تحميل المنتجات: $err',
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  data: (prods) {
                    if (prods.isEmpty) {
                      return Center(
                        child: Text(
                          'لا توجد منتجات مضافة بالمخزن حتى الآن',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.textTertiary,
                            fontSize: 14.sp,
                          ),
                        ),
                      );
                    }
                    if (filteredProducts.isEmpty) {
                      return Center(
                        child: Text(
                          'لا توجد منتجات تطابق كلمة البحث',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.textTertiary,
                            fontSize: 14.sp,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final actual =
                            _actualQuantities[product.id] ??
                            product.currentQuantity;
                        final diff = actual - product.currentQuantity;
                        final isSurplus = diff > 0;
                        final isDeficit = diff < 0;

                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 2.h,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.nameAr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    fontSize: 14.sp,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (product.internalCode != null &&
                                  product.internalCode!.isNotEmpty) ...[
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    product.internalCode!,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontFamily: 'Cairo',
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'الرصيد الدفتري (النظام): ${product.currentQuantity}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isSurplus
                                      ? AppColors.successLight
                                      : isDeficit
                                      ? AppColors.errorLight
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  isSurplus
                                      ? 'فائض (+${diff.toStringAsFixed(1)})'
                                      : isDeficit
                                      ? 'عجز (-${diff.abs().toStringAsFixed(1)})'
                                      : 'مطابق',
                                  style: TextStyle(
                                    color: isSurplus
                                        ? AppColors.success
                                        : isDeficit
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              SizedBox(
                                width: 110.w,
                                child: TextFormField(
                                  key: ValueKey('prod_qty_${product.id}'),
                                  initialValue: actual.toString(),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'الفعلي',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    final parsed =
                                        double.tryParse(val) ??
                                        product.currentQuantity;
                                    setState(() {
                                      _actualQuantities[product.id] = parsed;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 10.h),

            // Footer Toolbar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'إجمالي الفروقات: ',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                          Text(
                            'فائض (+${totalSurplus.toStringAsFixed(1)})  |  ',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                          Text(
                            'عجز (-${totalDeficit.toStringAsFixed(1)})',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                    ),
                    onPressed: _isSaving ? null : () => _saveCount(allProducts),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.checkCheck, size: 18),
                    label: Text(
                      _isSaving ? 'جاري التصفية...' : 'حفظ واعتماد تسوية الجرد',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCount(List<Product> allProducts) async {
    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);

      await db.transaction(() async {
        final countId = await db
            .into(db.inventoryCounts)
            .insert(
              InventoryCountsCompanion.insert(
                name: _nameController.text,
                type: _type,
                status: const drift.Value('completed'),
                userId: 1,
                completedAt: drift.Value(DateTime.now()),
              ),
            );

        for (final product in allProducts) {
          final actual =
              _actualQuantities[product.id] ?? product.currentQuantity;
          final system = product.currentQuantity;
          final diff = actual - system;

          if (diff != 0) {
            await db
                .into(db.inventoryCountItems)
                .insert(
                  InventoryCountItemsCompanion.insert(
                    inventoryCountId: countId,
                    productId: product.id,
                    systemQuantity: system,
                    actualQuantity: drift.Value(actual),
                    difference: drift.Value(diff),
                  ),
                );

            await (db.update(db.products)
                  ..where((t) => t.id.equals(product.id)))
                .write(ProductsCompanion(currentQuantity: drift.Value(actual)));

            await db
                .into(db.stockMovements)
                .insert(
                  StockMovementsCompanion.insert(
                    productId: product.id,
                    movementType: 'ADJUSTMENT',
                    quantity: diff.abs(),
                    referenceType: const drift.Value('inventory_count'),
                    referenceId: drift.Value(countId),
                    userId: 1,
                    notes: drift.Value(
                      diff > 0 ? 'فائض جرد مخزني' : 'عجز جرد مخزني',
                    ),
                  ),
                );
          }
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ واعتماد تسوية الجرد بنجاح وتحديث أرصدة المخزن!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء حفظ الجرد: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
