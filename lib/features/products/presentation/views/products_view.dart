import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/utils/barcode_scanner_handler.dart';

class ProductsView extends ConsumerStatefulWidget {
  const ProductsView({super.key});

  @override
  ConsumerState<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends ConsumerState<ProductsView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedCategoryId;
  late final BarcodeScannerHandler _scannerHandler;

  @override
  void initState() {
    super.initState();
    _scannerHandler = BarcodeScannerHandler(
      onBarcodeScanned: (barcode) {
        if (mounted) {
          _onHardwareBarcodeScanned(barcode);
        }
      },
    );
    _scannerHandler.start();
  }

  @override
  void dispose() {
    _scannerHandler.stop();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onHardwareBarcodeScanned(String barcode) async {
    final db = ref.read(databaseProvider);
    final cleaned = barcode.trim();
    if (cleaned.isEmpty) return;

    final barcodeRecord = await (db.select(
      db.productBarcodes,
    )..where((t) => t.barcode.equals(cleaned))).getSingleOrNull();

    Product? foundProduct;
    if (barcodeRecord != null) {
      foundProduct = await (db.select(db.products)
        ..where((t) => t.id.equals(barcodeRecord.productId))).getSingleOrNull();
    }

    foundProduct ??= await (db.select(db.products)
      ..where((t) => t.internalCode.equals(cleaned))).getSingleOrNull();

    if (foundProduct != null) {
      setState(() {
        _searchQuery = cleaned;
        _searchController.text = cleaned;
      });
      if (mounted) {
        AppErrorHandler.showSuccessSnackBar(
          context,
          'تم العثور على المنتج: ${foundProduct.nameAr}',
        );
      }
    } else {
      setState(() {
        _searchQuery = cleaned;
        _searchController.text = cleaned;
      });
      if (mounted) {
        AppErrorHandler.showWarningSnackBar(
          context,
          'الباركود "$cleaned" غير مسجل. يمكنك إضافته الآن.',
        );
        _showAddProductDialog(initialBarcode: cleaned);
      }
    }
  }

  void _showAddProductDialog({String? initialBarcode}) {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(initialBarcode: initialBarcode),
    );
  }

  void _showScanBarcodeAddDialog() {
    showDialog(
      context: context,
      builder: (context) => const ScanBarcodeAddDialog(),
    );
  }

  void _showProductDetailsDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => ProductDetailsDialog(product: product),
    );
  }

  void _showEditProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => EditProductDialog(product: product),
    );
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text(
              'تأكيد الحذف',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف المنتج "${product.nameAr}"؟\nسوف يتم حذف جميع الباركودات المرتبطة به. لا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'حذف المنتج',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final db = ref.read(databaseProvider);
        await DbHelpers.deleteProduct(db, product.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'تم حذف المنتج بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'فشل حذف المنتج: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final barcodesAsync = ref.watch(productBarcodesStreamProvider);

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
                        'إدارة المنتجات',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'عرض، إضافة، وتعديل المنتجات وأسعار الجملة والتجزئة والباركود',
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
                  onPressed: _showScanBarcodeAddDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(LucideIcons.scanLine, size: 18),
                  label: const Text(
                    'إضافة بالباركود',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddProductDialog(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text(
                    'منتج جديد',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Search and filter bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم، الكود، أو الباركود...',
                        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  categoriesAsync.when(
                    data: (categories) {
                      return DropdownButton<int?>(
                        value: _selectedCategoryId,
                        hint: const Text(
                          'كل التصنيفات',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 15),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'كل التصنيفات',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 15),
                            ),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(
                                c.name,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedCategoryId = val),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Table content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: productsAsync.when(
                  data: (products) {
                    final allBarcodes = barcodesAsync.asData?.value ?? [];
                    final matchingBarcodeProductIds = allBarcodes
                        .where((b) =>
                            _searchQuery.isNotEmpty &&
                            b.barcode.toLowerCase().contains(_searchQuery.toLowerCase()))
                        .map((b) => b.productId)
                        .toSet();

                    final filtered = products.where((p) {
                      final query = _searchQuery.toLowerCase();
                      final matchesSearch = query.isEmpty ||
                          p.nameAr.toLowerCase().contains(query) ||
                          (p.nameEn != null &&
                              p.nameEn!.toLowerCase().contains(query)) ||
                          (p.internalCode != null &&
                              p.internalCode!.toLowerCase().contains(query)) ||
                          matchingBarcodeProductIds.contains(p.id);
                      final matchesCat = _selectedCategoryId == null ||
                          p.categoryId == _selectedCategoryId;
                      return matchesSearch && matchesCat;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.packageSearch,
                              size: 48,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              products.isEmpty
                                  ? 'لا يوجد منتجات مضافين حالياً'
                                  : 'لم يتم العثور على نتائج مطابقة',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            if (products.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddProductDialog,
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text(
                                  'إضافة أول منتج',
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final isLowStock =
                            product.currentQuantity <= product.minQuantity;

                        final productBarcodes = allBarcodes
                            .where((b) => b.productId == product.id)
                            .toList();
                        final primaryBarcode = productBarcodes.firstWhere(
                          (b) => b.isPrimary,
                          orElse: () => productBarcodes.isNotEmpty
                              ? productBarcodes.first
                              : const ProductBarcode(
                                  id: -1,
                                  productId: -1,
                                  barcode: '',
                                  isPrimary: false,
                                ),
                        );

                        return InkWell(
                          onTap: () => _showProductDetailsDialog(product),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isLowStock
                                        ? AppColors.error.withValues(alpha: 0.1)
                                        : AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.box,
                                    color: isLowStock
                                        ? AppColors.error
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            product.nameAr,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                          if (product.internalCode != null &&
                                              product
                                                  .internalCode!
                                                  .isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'كود: ${product.internalCode!}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontFamily: 'Cairo',
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (primaryBarcode.barcode.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primarySurface,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    LucideIcons.qrCode,
                                                    size: 13,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    primaryBarcode.barcode,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                      fontFamily: 'Cairo',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'شراء: ${product.purchasePrice.toStringAsFixed(2)} | قطاعي: ${product.retailPrice.toStringAsFixed(2)} | جملة: ${product.wholesalePrice.toStringAsFixed(2)} ج.م',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'الكمية: ${product.currentQuantity.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isLowStock
                                            ? AppColors.error
                                            : AppColors.textPrimary,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    if (isLowStock)
                                      const Text(
                                        'تنبيه: مخزون منخفض',
                                        style: TextStyle(
                                          color: AppColors.error,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Action Buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.eye,
                                        size: 18,
                                      ),
                                      color: AppColors.primary,
                                      tooltip: 'عرض التفاصيل',
                                      onPressed: () =>
                                          _showProductDetailsDialog(product),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.edit2,
                                        size: 18,
                                      ),
                                      color: AppColors.textSecondary,
                                      tooltip: 'تعديل البيانات',
                                      onPressed: () =>
                                          _showEditProductDialog(product),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.trash2,
                                        size: 18,
                                      ),
                                      color: AppColors.error,
                                      tooltip: 'حذف المنتج',
                                      onPressed: () =>
                                          _confirmDeleteProduct(product),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(
                      'خطأ: $err',
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to view full product details
class ProductDetailsDialog extends ConsumerWidget {
  final Product product;
  const ProductDetailsDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLowStock = product.currentQuantity <= product.minQuantity;
    final db = ref.watch(databaseProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLowStock
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.box,
                      color: isLowStock ? AppColors.error : AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.nameAr,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        if (product.nameEn != null &&
                            product.nameEn!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.nameEn!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Stock Status Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLowStock
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLowStock
                        ? AppColors.error.withValues(alpha: 0.3)
                        : AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLowStock
                          ? LucideIcons.alertTriangle
                          : LucideIcons.packageCheck,
                      color: isLowStock ? AppColors.error : AppColors.success,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المخزون الحالي',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '${product.currentQuantity.toStringAsFixed(0)} وحدة  (حد الإنذار: ${product.minQuantity.toStringAsFixed(0)})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isLowStock
                                  ? AppColors.error
                                  : AppColors.success,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isLowStock ? AppColors.error : AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLowStock ? 'مخزون حرج' : 'مخزون متوفر',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pricing Grid
              const Text(
                'أسعار المنتج',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildPriceCard(
                      label: 'سعر الشراء',
                      amount: product.purchasePrice,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPriceCard(
                      label: 'سعر القطاعي',
                      amount: product.retailPrice,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPriceCard(
                      label: 'سعر الجملة',
                      amount: product.wholesalePrice,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Other Details
              const Text(
                'بيانات إضافية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: LucideIcons.hash,
                label: 'الكود الداخلي',
                value: product.internalCode ?? 'غير محدد',
              ),
              const SizedBox(height: 10),
              FutureBuilder<ProductBarcode?>(
                future:
                    (db.select(db.productBarcodes)..where(
                          (t) =>
                              t.productId.equals(product.id) &
                              t.isPrimary.equals(true),
                        ))
                        .getSingleOrNull(),
                builder: (context, snapshot) {
                  final barcodeStr = snapshot.data?.barcode ?? 'غير مسجل';
                  return _buildDetailRow(
                    icon: LucideIcons.qrCode,
                    label: 'الباركود الرئيسي',
                    value: barcodeStr,
                  );
                },
              ),
              const SizedBox(height: 10),
              categoriesAsync.when(
                data: (cats) {
                  final cat = cats
                      .where((c) => c.id == product.categoryId)
                      .firstOrNull;
                  return _buildDetailRow(
                    icon: LucideIcons.folder,
                    label: 'التصنيف',
                    value: cat?.name ?? 'بدون تصنيف',
                  );
                },
                loading: () => _buildDetailRow(
                  icon: LucideIcons.folder,
                  label: 'التصنيف',
                  value: 'جاري التحميل...',
                ),
                error: (_, __) => _buildDetailRow(
                  icon: LucideIcons.folder,
                  label: 'التصنيف',
                  value: 'غير محدد',
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (context) =>
                            EditProductDialog(product: product),
                      );
                    },
                    icon: const Icon(LucideIcons.edit2, size: 16),
                    label: const Text(
                      'تعديل البيانات',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'إغلاق',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceCard({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog to edit product
class EditProductDialog extends ConsumerStatefulWidget {
  final Product product;
  const EditProductDialog({super.key, required this.product});

  @override
  ConsumerState<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _retailPriceController;
  late final TextEditingController _wholesalePriceController;
  late final TextEditingController _minQtyController;
  late final TextEditingController _qtyController;
  late final TextEditingController _categoryController;
  int? _selectedCategoryId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.nameAr);
    _codeController = TextEditingController(
      text: widget.product.internalCode ?? '',
    );
    _barcodeController = TextEditingController();
    _purchasePriceController = TextEditingController(
      text: widget.product.purchasePrice.toString(),
    );
    _retailPriceController = TextEditingController(
      text: widget.product.retailPrice.toString(),
    );
    _wholesalePriceController = TextEditingController(
      text: widget.product.wholesalePrice.toString(),
    );
    _minQtyController = TextEditingController(
      text: widget.product.minQuantity.toString(),
    );
    _qtyController = TextEditingController(
      text: widget.product.currentQuantity.toString(),
    );
    _categoryController = TextEditingController();
    _selectedCategoryId = widget.product.categoryId;

    _loadBarcode();
    _loadCategoryName();
  }

  Future<void> _loadCategoryName() async {
    if (widget.product.categoryId != null) {
      final db = ref.read(databaseProvider);
      final cat = await (db.select(db.categories)..where((t) => t.id.equals(widget.product.categoryId!)))
          .getSingleOrNull();
      if (cat != null && mounted) {
        setState(() {
          _categoryController.text = cat.name;
        });
      }
    }
  }

  Future<void> _loadBarcode() async {
    final db = ref.read(databaseProvider);
    final barcodeObj =
        await (db.select(db.productBarcodes)..where(
              (t) =>
                  t.productId.equals(widget.product.id) &
                  t.isPrimary.equals(true),
            ))
            .getSingleOrNull();
    if (barcodeObj != null && mounted) {
      _barcodeController.text = barcodeObj.barcode;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _retailPriceController.dispose();
    _wholesalePriceController.dispose();
    _minQtyController.dispose();
    _qtyController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);

      // Resolve category: find existing or create new
      int? categoryId = _selectedCategoryId;
      final categoryName = _categoryController.text.trim();
      if (categoryName.isNotEmpty && categoryId == null) {
        final existingCats = await db.select(db.categories).get();
        final match = existingCats.where((c) => c.name == categoryName).toList();
        if (match.isNotEmpty) {
          categoryId = match.first.id;
        } else {
          categoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(name: categoryName),
          );
        }
      }
      if (categoryName.isEmpty) {
        categoryId = null;
      }

      await DbHelpers.updateProduct(
        db,
        id: widget.product.id,
        nameAr: _nameController.text.trim(),
        internalCode: _codeController.text.trim().isEmpty
            ? null
            : _codeController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        categoryId: categoryId,
        purchasePrice:
            double.tryParse(_purchasePriceController.text.trim()) ?? 0.0,
        retailPrice: double.tryParse(_retailPriceController.text.trim()) ?? 0.0,
        wholesalePrice:
            double.tryParse(_wholesalePriceController.text.trim()) ?? 0.0,
        minQuantity: double.tryParse(_minQtyController.text.trim()) ?? 0.0,
      );

      final newQty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
      final delta = newQty - widget.product.currentQuantity;
      if (delta != 0) {
        await DbHelpers.updateProductStock(
          db: db,
          productId: widget.product.id,
          quantityDelta: delta,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تحديث بيانات المنتج بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ في التحديث: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'تعديل بيانات المنتج',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'الرجاء إدخال اسم المنتج'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'كود المنتج الداخلي',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'الباركود',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                categoriesAsync.when(
                  data: (categories) {
                    return Autocomplete<Category>(
                      initialValue: TextEditingValue(text: _categoryController.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.trim().isEmpty) {
                          return categories;
                        }
                        return categories.where((c) => c.name
                            .contains(textEditingValue.text.trim()));
                      },
                      displayStringForOption: (Category c) => c.name,
                      onSelected: (Category selection) {
                        setState(() {
                          _selectedCategoryId = selection.id;
                          _categoryController.text = selection.name;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        if (_categoryController.text.isNotEmpty && controller.text.isEmpty) {
                          controller.text = _categoryController.text;
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'التصنيف (اكتب اسم التصنيف)',
                            hintText: 'اكتب اسم التصنيف أو اختر من القائمة...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(LucideIcons.folder),
                          ),
                          style: const TextStyle(fontFamily: 'Cairo'),
                          onChanged: (val) {
                            _categoryController.text = val;
                            final match = categories.where((c) => c.name == val.trim()).toList();
                            if (match.isNotEmpty) {
                              _selectedCategoryId = match.first.id;
                            } else {
                              _selectedCategoryId = null;
                            }
                          },
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topRight,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final cat = options.elementAt(index);
                                  return ListTile(
                                    title: Text(cat.name, style: const TextStyle(fontFamily: 'Cairo')),
                                    leading: const Icon(LucideIcons.folder, size: 18),
                                    onTap: () => onSelected(cat),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف (اكتب اسم التصنيف)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر الشراء (ج.م)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _retailPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر البيع قطاعي (ج.م)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _wholesalePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر البيع جملة (ج.م)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الكمية الحالية',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الحد الأدنى للإنذار بالمخزون',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'حفظ التغييرات',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog to add a new product
class AddProductDialog extends ConsumerStatefulWidget {
  final String? initialBarcode;
  const AddProductDialog({super.key, this.initialBarcode});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _purchasePriceController = TextEditingController(text: '0');
  final _retailPriceController = TextEditingController(text: '0');
  final _wholesalePriceController = TextEditingController(text: '0');
  final _initialQtyController = TextEditingController(text: '0');
  final _minQtyController = TextEditingController(text: '5');
  final _categoryController = TextEditingController();
  int? _selectedCategoryId;
  bool _isLoading = false;
  late final BarcodeScannerHandler _dialogScanner;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!;
    }
    _dialogScanner = BarcodeScannerHandler(
      onBarcodeScanned: (barcode) {
        if (mounted) {
          setState(() {
            _barcodeController.text = barcode;
          });
          AppErrorHandler.showSuccessSnackBar(
            context,
            'تم التقاط الباركود: $barcode',
          );
        }
      },
    );
    _dialogScanner.start();
  }

  @override
  void dispose() {
    _dialogScanner.stop();
    _nameController.dispose();
    _codeController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _retailPriceController.dispose();
    _wholesalePriceController.dispose();
    _initialQtyController.dispose();
    _minQtyController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final userId = ref.read(currentUserIdProvider) ?? 1;

      // Resolve category: find existing or create new
      int? categoryId = _selectedCategoryId;
      final categoryName = _categoryController.text.trim();
      if (categoryName.isNotEmpty && categoryId == null) {
        // Check if category exists by name
        final existingCats = await db.select(db.categories).get();
        final match = existingCats.where((c) => c.name == categoryName).toList();
        if (match.isNotEmpty) {
          categoryId = match.first.id;
        } else {
          // Create new category
          categoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(name: categoryName),
          );
        }
      }

      await DbHelpers.addProduct(
        db,
        nameAr: _nameController.text.trim(),
        internalCode: _codeController.text.trim().isEmpty
            ? null
            : _codeController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        categoryId: categoryId,
        purchasePrice:
            double.tryParse(_purchasePriceController.text.trim()) ?? 0.0,
        retailPrice: double.tryParse(_retailPriceController.text.trim()) ?? 0.0,
        wholesalePrice:
            double.tryParse(_wholesalePriceController.text.trim()) ?? 0.0,
        initialQuantity:
            double.tryParse(_initialQtyController.text.trim()) ?? 0.0,
        minQuantity: double.tryParse(_minQtyController.text.trim()) ?? 0.0,
        userId: userId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تمت إضافة المنتج بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'إضافة منتج جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'الرجاء إدخال اسم المنتج'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'كود المنتج الداخلي',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'الباركود',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                categoriesAsync.when(
                  data: (categories) {
                    return Autocomplete<Category>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.trim().isEmpty) {
                          return categories;
                        }
                        return categories.where((c) => c.name
                            .contains(textEditingValue.text.trim()));
                      },
                      displayStringForOption: (Category c) => c.name,
                      onSelected: (Category selection) {
                        setState(() {
                          _selectedCategoryId = selection.id;
                          _categoryController.text = selection.name;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        // Sync internal controller with our state
                        if (_categoryController.text.isNotEmpty && controller.text.isEmpty) {
                          controller.text = _categoryController.text;
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'التصنيف (اكتب اسم التصنيف)',
                            hintText: 'اكتب اسم التصنيف أو اختر من القائمة...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(LucideIcons.folder),
                          ),
                          style: const TextStyle(fontFamily: 'Cairo'),
                          onChanged: (val) {
                            _categoryController.text = val;
                            // Reset selected ID if text changed manually
                            final match = categories.where((c) => c.name == val.trim()).toList();
                            if (match.isNotEmpty) {
                              _selectedCategoryId = match.first.id;
                            } else {
                              _selectedCategoryId = null;
                            }
                          },
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topRight,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final cat = options.elementAt(index);
                                  return ListTile(
                                    title: Text(cat.name, style: const TextStyle(fontFamily: 'Cairo')),
                                    leading: const Icon(LucideIcons.folder, size: 18),
                                    onTap: () => onSelected(cat),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف (اكتب اسم التصنيف)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر الشراء (ج.م)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _retailPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر البيع قطاعي (ج.م)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _wholesalePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر البيع جملة (ج.م)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _initialQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الكمية الافتتاحية في المخزن',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الحد الأدنى للإنذار',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'حفظ المنتج',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog for rapid scanning to find or add products
class ScanBarcodeAddDialog extends ConsumerStatefulWidget {
  const ScanBarcodeAddDialog({super.key});

  @override
  ConsumerState<ScanBarcodeAddDialog> createState() =>
      _ScanBarcodeAddDialogState();
}

class _ScanBarcodeAddDialogState extends ConsumerState<ScanBarcodeAddDialog> {
  final _barcodeInputController = TextEditingController();
  late final BarcodeScannerHandler _scannerHandler;
  bool _isSearching = false;
  String? _lastScannedBarcode;
  Product? _foundProduct;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _scannerHandler = BarcodeScannerHandler(
      onBarcodeScanned: (barcode) {
        if (mounted) {
          _barcodeInputController.text = barcode;
          _processBarcode(barcode);
        }
      },
    );
    _scannerHandler.start();
  }

  @override
  void dispose() {
    _scannerHandler.stop();
    _barcodeInputController.dispose();
    super.dispose();
  }

  Future<void> _processBarcode(String barcode) async {
    final cleaned = barcode.trim();
    if (cleaned.isEmpty) return;

    setState(() {
      _isSearching = true;
      _lastScannedBarcode = cleaned;
      _hasSearched = true;
      _foundProduct = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final barcodeRecord = await (db.select(
        db.productBarcodes,
      )..where((t) => t.barcode.equals(cleaned))).getSingleOrNull();

      if (barcodeRecord != null) {
        final product =
            await (db.select(db.products)
                  ..where((t) => t.id.equals(barcodeRecord.productId)))
                .getSingleOrNull();

        setState(() {
          _foundProduct = product;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.scanLine,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ماسح الباركود السريع',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        'قم بمسح باركود المنتج لإضافته أو البحث عنه',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _barcodeInputController,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'رقم الباركود',
                hintText: 'وجّه الماسح أو اكتب الباركود هنا...',
                prefixIcon: const Icon(LucideIcons.scanLine),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.arrowRight),
                  onPressed: () =>
                      _processBarcode(_barcodeInputController.text),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _processBarcode,
            ),
            const SizedBox(height: 20),
            if (_isSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_hasSearched) ...[
              if (_foundProduct != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.checkCircle2,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _foundProduct!.nameAr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Text(
                              'سعر البيع: ${_foundProduct!.retailPrice} ج.م | المخزون: ${_foundProduct!.currentQuantity}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade900,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.alertCircle,
                            color: Colors.amber,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'الباركود "$_lastScannedBarcode" غير مسجل لقواعد البيانات',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              builder: (context) => AddProductDialog(
                                initialBarcode: _lastScannedBarcode,
                              ),
                            );
                          },
                          icon: const Icon(LucideIcons.plus),
                          label: const Text(
                            'إضافة هذا المنتج الآن',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.scan,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'بانتظار مسح الباركود من قارئ الباركود...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'إغلاق',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
