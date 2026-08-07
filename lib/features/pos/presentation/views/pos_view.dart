import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/utils/barcode_scanner_handler.dart';

/// Point of Sale - Full screen view
class PosView extends ConsumerStatefulWidget {
  const PosView({super.key});

  @override
  ConsumerState<PosView> createState() => _PosViewState();
}

class _PosViewState extends ConsumerState<PosView> {
  final _barcodeController = TextEditingController();
  final _barcodeFocus = FocusNode();
  late final BarcodeScannerHandler _scannerHandler;

  final List<PosCartItem> _cartItems = [];
  Customer? _selectedCustomer;
  String _paymentMethod = 'cash'; // 'cash' or 'credit'
  double _overallDiscount = 0.0;
  int _suspendedCount = 0;

  @override
  void initState() {
    super.initState();
    _barcodeFocus.requestFocus();
    _loadSuspendedCount();

    _scannerHandler = BarcodeScannerHandler(
      onBarcodeScanned: (barcode) {
        if (mounted) {
          _searchAndAddProduct(barcode);
        }
      },
    );
    _scannerHandler.start();
  }

  @override
  void dispose() {
    _scannerHandler.stop();
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSuspendedCount() async {
    final db = ref.read(databaseProvider);
    final list = await DbHelpers.getSuspendedInvoices(db);
    if (mounted) {
      setState(() {
        _suspendedCount = list.length;
      });
    }
  }

  double get _subtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.total);

  double get _total {
    final t = _subtotal - _overallDiscount;
    return t < 0 ? 0.0 : t;
  }

  void _addToCart(Product product, {double qty = 1.0}) {
    setState(() {
      final index =
          _cartItems.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        final existing = _cartItems[index];
        _cartItems[index] = PosCartItem(
          product: existing.product,
          quantity: existing.quantity + qty,
          unitPrice: existing.unitPrice,
          discount: existing.discount,
        );
      } else {
        _cartItems.add(
          PosCartItem(
            product: product,
            quantity: qty,
            unitPrice: product.retailPrice,
            discount: 0.0,
          ),
        );
      }
    });
    if (mounted) {
      AppErrorHandler.showSuccessSnackBar(
        context,
        'تمت إضافة "${product.nameAr}" إلى الفاتورة',
      );
    }
  }

  void _updateItemQuantity(int index, double newQty) {
    if (newQty <= 0) {
      _removeItem(index);
      return;
    }
    setState(() {
      final existing = _cartItems[index];
      _cartItems[index] = PosCartItem(
        product: existing.product,
        quantity: newQty,
        unitPrice: existing.unitPrice,
        discount: existing.discount,
      );
    });
  }

  void _updateItemUnitPrice(int index, double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      final existing = _cartItems[index];
      _cartItems[index] = PosCartItem(
        product: existing.product,
        quantity: existing.quantity,
        unitPrice: newPrice,
        discount: existing.discount,
      );
    });
  }

  void _updateItemDiscount(int index, double newDiscount) {
    if (newDiscount < 0) return;
    setState(() {
      final existing = _cartItems[index];
      _cartItems[index] = PosCartItem(
        product: existing.product,
        quantity: existing.quantity,
        unitPrice: existing.unitPrice,
        discount: newDiscount,
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _resetInvoice() {
    setState(() {
      _cartItems.clear();
      _selectedCustomer = null;
      _paymentMethod = 'cash';
      _overallDiscount = 0.0;
    });
    _barcodeController.clear();
    _barcodeFocus.requestFocus();
  }

  Future<void> _searchAndAddProduct(String query) async {
    final db = ref.read(databaseProvider);
    final cleaned = query.trim();

    if (cleaned.isEmpty) {
      final allProducts = await db.select(db.products).get();
      if (allProducts.isEmpty) {
        if (mounted) {
          AppErrorHandler.showWarningSnackBar(
            context,
            'لا توجد منتجات مسجلة بالنظام. قم بإنشاء منتجات أولاً',
          );
        }
      } else {
        if (mounted) {
          _showProductSelectionDialog(allProducts);
        }
      }
      return;
    }

    // 1. Search Barcodes table
    final barcodeRecord = await (db.select(db.productBarcodes)
          ..where((t) => t.barcode.equals(cleaned)))
        .getSingleOrNull();

    Product? foundProduct;
    if (barcodeRecord != null) {
      foundProduct = await (db.select(db.products)
            ..where((t) => t.id.equals(barcodeRecord.productId)))
          .getSingleOrNull();
    }

    // 2. Search by internal code
    foundProduct ??= await (db.select(db.products)
          ..where((t) => t.internalCode.equals(cleaned)))
        .getSingleOrNull();

    // 3. Search by name (contains)
    if (foundProduct == null) {
      final matches = await (db.select(db.products)
            ..where((t) =>
                t.nameAr.contains(cleaned) |
                (t.nameEn.isNotNull() & t.nameEn.contains(cleaned))))
          .get();

      if (matches.length == 1) {
        foundProduct = matches.first;
      } else if (matches.length > 1) {
        _showProductSelectionDialog(matches);
        _barcodeController.clear();
        _barcodeFocus.requestFocus();
        return;
      }
    }

    if (foundProduct != null) {
      _addToCart(foundProduct);
    } else {
      if (mounted) {
        AppErrorHandler.showWarningSnackBar(
          context,
          'المنتج غير موجود: "$cleaned"',
        );
        final allProducts = await db.select(db.products).get();
        if (allProducts.isNotEmpty) {
          _showProductSelectionDialog(allProducts);
        }
      }
    }

    _barcodeController.clear();
    _barcodeFocus.requestFocus();
  }

  void _showProductSelectionDialog(List<Product> products) {
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = products.where((p) {
            if (query.isEmpty) return true;
            return p.nameAr.toLowerCase().contains(query) ||
                (p.nameEn ?? '').toLowerCase().contains(query) ||
                (p.internalCode ?? '').contains(query);
          }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.package,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'اختر من القائمة (${filtered.length})',
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'تصفية باسم أو كود المنتج...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد منتجات تطابق البحث',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: AppColors.textTertiary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final prod = filtered[index];
                                return ListTile(
                                  title: Text(
                                    prod.nameAr,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'الكود: ${prod.internalCode ?? "-"} | الرصيد: ${prod.currentQuantity} | السعر: ${prod.retailPrice.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                        fontFamily: 'Cairo', fontSize: 12),
                                  ),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () {
                                      _addToCart(prod);
                                      Navigator.pop(dialogContext);
                                    },
                                    icon:
                                        const Icon(LucideIcons.plus, size: 14),
                                    label: const Text(
                                      'إضافة',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    _addToCart(prod);
                                    Navigator.pop(dialogContext);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إغلاق',
                      style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQrScannerDialog() {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final productsAsync = ref.watch(productsStreamProvider);

              return Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.scanLine, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'ماسح الباركود والـ QR Code',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Simulated Camera View Box
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.qrCode,
                                size: 64,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'جهاز المسح الضوئي يعمل تلقائياً عند قراءة الباركود',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'مسح الباركود أو إدخال كود المنتج...',
                            prefixIcon: const Icon(LucideIcons.qrCode, color: AppColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (val) => setDialogState(() {}),
                          onSubmitted: (val) async {
                            if (val.trim().isNotEmpty) {
                              await _searchAndAddProduct(val);
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'أو اختر من القائمة السريعة:',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: productsAsync.when(
                            data: (products) {
                              final filtered = products.where((p) {
                                final q = searchController.text.toLowerCase();
                                if (q.isEmpty) return true;
                                return p.nameAr.toLowerCase().contains(q) ||
                                    (p.internalCode ?? '').contains(q);
                              }).toList();

                              if (filtered.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'لا توجد منتجات',
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                );
                              }

                              return ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final p = filtered[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      p.nameAr,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'الرصيد: ${p.currentQuantity}',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                                    ),
                                    trailing: ElevatedButton.icon(
                                      onPressed: () {
                                        _addToCart(p);
                                        Navigator.pop(dialogContext);
                                      },
                                      icon: const Icon(LucideIcons.plus, size: 14),
                                      label: const Text(
                                        'إضافة',
                                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCustomerSelectionDialog() {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final customersAsync = ref.watch(customersStreamProvider);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(LucideIcons.userCheck, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'تحديد العميل',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: 420,
                child: Column(
                  children: [
                    // Cash customer option button
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: _selectedCustomer == null
                              ? AppColors.primary
                              : AppColors.border,
                          width: _selectedCustomer == null ? 2 : 1,
                        ),
                      ),
                      tileColor: _selectedCustomer == null
                          ? AppColors.primarySurface
                          : Colors.grey.shade50,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Icon(LucideIcons.user, color: Colors.white, size: 18),
                      ),
                      title: const Text(
                        'عميل نقدي (افتراضي)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'للمبيعات النقدية المباشرة بدون تسجيل بيانات العميل',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
                      ),
                      trailing: _selectedCustomer == null
                          ? const Icon(LucideIcons.checkCircle2, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCustomer = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم العميل أو رقم الهاتف...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: customersAsync.when(
                        data: (customers) {
                          final query = searchController.text.trim().toLowerCase();
                          final filtered = customers.where((c) {
                            if (query.isEmpty) return true;
                            return c.name.toLowerCase().contains(query) ||
                                (c.phone ?? '').contains(query);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text(
                                'لا يوجد عملاء مطبقون',
                                style: TextStyle(fontFamily: 'Cairo'),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final cust = filtered[index];
                              final isSelected = _selectedCustomer?.id == cust.id;

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: AppColors.primarySurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                title: Text(
                                  cust.name,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'الهاتف: ${cust.phone ?? "غير مسجل"} | الرصيد: ${cust.balance.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                                ),
                                trailing: isSelected
                                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCustomer = cust;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddQuickCustomerDialog();
                  },
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  label: const Text(
                    'إضافة عميل جديد',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  ),
);
}

  void _showAddQuickCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(LucideIcons.userPlus, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'إضافة عميل جديد سريح',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'برجاء إدخال الاسم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                  ),
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final db = ref.read(databaseProvider);
                  final id = await DbHelpers.addCustomer(
                    db,
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  );
                  final newCust = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
                  setState(() {
                    _selectedCustomer = newCust;
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ واختيار', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountDialog() {
    final discountCtrl = TextEditingController(text: _overallDiscount.toString());

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(LucideIcons.percent, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'إضافة خصم على الفاتورة',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'قيمة الخصم (ج.م)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () {
                final d = double.tryParse(discountCtrl.text) ?? 0.0;
                setState(() {
                  _overallDiscount = d < 0 ? 0.0 : d;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('تطبيق الخصم', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _suspendInvoice() async {
    if (_cartItems.isEmpty) {
      AppErrorHandler.showWarningSnackBar(context, 'الفاتورة فارغة لا يمكن تعليقها');
      return;
    }

    final db = ref.read(databaseProvider);
    final userId = ref.read(currentUserIdProvider) ?? 1;

    final invoiceData = {
      'customer': _selectedCustomer == null
          ? null
          : {
              'id': _selectedCustomer!.id,
              'name': _selectedCustomer!.name,
            },
      'paymentMethod': _paymentMethod,
      'overallDiscount': _overallDiscount,
      'items': _cartItems
          .map((item) => {
                'productId': item.product.id,
                'productName': item.product.nameAr,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'discount': item.discount,
              })
          .toList(),
    };

    await DbHelpers.suspendSalesInvoice(
      db,
      invoiceDataJson: jsonEncode(invoiceData),
      userId: userId,
      customerName: _selectedCustomer?.name ?? 'عميل نقدي',
    );

    await _loadSuspendedCount();
    _resetInvoice();

    if (mounted) {
      AppErrorHandler.showSuccessSnackBar(context, 'تم تعليق الفاتورة بنجاح');
    }
  }

  Future<void> _showSuspendedInvoicesDialog() async {
    final db = ref.read(databaseProvider);
    final suspendedList = await DbHelpers.getSuspendedInvoices(db);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.pauseCircle, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'الفواتير المعلقة (${suspendedList.length})',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 380,
            child: suspendedList.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد فواتير معلقة حالياً',
                      style: TextStyle(fontFamily: 'Cairo', color: AppColors.textTertiary),
                    ),
                  )
                : ListView.separated(
                    itemCount: suspendedList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = suspendedList[index];
                      final dt = item.createdAt;
                      final formattedDate =
                          '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, "0")}';

                      Map<String, dynamic> data = {};
                      try {
                        data = jsonDecode(item.invoiceDataJson);
                      } catch (_) {}

                      final itemsList = (data['items'] as List?) ?? [];

                      return ListTile(
                        title: Text(
                          'عميل: ${item.customerName ?? "عميل نقدي"}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'عدد الأصناف: ${itemsList.length} | التاريخ: $formattedDate',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _restoreSuspendedInvoice(item);
                              },
                              icon: const Icon(LucideIcons.play, size: 14),
                              label: const Text(
                                'استرجاع',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                              onPressed: () async {
                                await DbHelpers.deleteSuspendedInvoice(db, item.id);
                                await _loadSuspendedCount();
                                if (context.mounted) Navigator.pop(context);
                                _showSuspendedInvoicesDialog();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreSuspendedInvoice(SuspendedInvoice suspended) async {
    final db = ref.read(databaseProvider);
    try {
      final Map<String, dynamic> data = jsonDecode(suspended.invoiceDataJson);
      final itemsData = (data['items'] as List?) ?? [];

      _cartItems.clear();
      for (final raw in itemsData) {
        final prodId = raw['productId'] as int;
        final qty = (raw['quantity'] as num).toDouble();
        final price = (raw['unitPrice'] as num).toDouble();
        final disc = (raw['discount'] as num).toDouble();

        final prod = await (db.select(db.products)..where((t) => t.id.equals(prodId))).getSingleOrNull();
        if (prod != null) {
          _cartItems.add(
            PosCartItem(
              product: prod,
              quantity: qty,
              unitPrice: price,
              discount: disc,
            ),
          );
        }
      }

      if (data['customer'] != null) {
        final custId = data['customer']['id'] as int;
        _selectedCustomer = await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingleOrNull();
      } else {
        _selectedCustomer = null;
      }

      _paymentMethod = (data['paymentMethod'] as String?) ?? 'cash';
      _overallDiscount = (data['overallDiscount'] as num?)?.toDouble() ?? 0.0;

      await DbHelpers.deleteSuspendedInvoice(db, suspended.id);
      await _loadSuspendedCount();
      setState(() {});

      if (mounted) {
        AppErrorHandler.showSuccessSnackBar(context, 'تم استرجاع الفاتورة المعلقة');
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showErrorDialog(context, e, title: 'خطأ في استرجاع الفاتورة');
      }
    }
  }

  Future<void> _saveAndPrintInvoice() async {
    if (_cartItems.isEmpty) {
      AppErrorHandler.showWarningSnackBar(context, 'برجاء إضافة منتجات للفاتورة أولاً');
      return;
    }

    if (_paymentMethod == 'credit' && _selectedCustomer == null) {
      AppErrorHandler.showErrorSnackBar(context, 'لا يمكن إكمال فاتورة آجل بدون تحديد عميل مسجل');
      return;
    }

    final db = ref.read(databaseProvider);
    final userId = ref.read(currentUserIdProvider) ?? 1;

    final paid = _paymentMethod == 'cash' ? _total : 0.0;

    try {
      final invoiceId = await DbHelpers.saveSalesInvoice(
        db,
        items: _cartItems,
        subtotal: _subtotal,
        discount: _overallDiscount,
        total: _total,
        paid: paid,
        paymentMethod: _paymentMethod,
        customerId: _selectedCustomer?.id,
        userId: userId,
      );

      final inv = await (db.select(db.invoices)..where((t) => t.id.equals(invoiceId))).getSingle();

      if (mounted) {
        await _showReceiptDialog(inv, _cartItems, _selectedCustomer);
        _resetInvoice();
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showErrorDialog(context, e, title: 'خطأ في حفظ الفاتورة');
      }
    }
  }

  Future<void> _showReceiptDialog(
    Invoice inv,
    List<PosCartItem> items,
    Customer? cust,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 54),
                const SizedBox(height: 10),
                const Text(
                  'تم حفظ الفاتورة بنجاح',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'رقم الفاتورة: ${inv.invoiceNumber}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'العميل: ${cust?.name ?? "عميل نقدي"}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    ),
                    Text(
                      'طريقة الدفع: ${inv.paymentMethod == "cash" ? "نقدي" : "آجل"}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final it = items[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                it.product.nameAr,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${it.quantity} x ${it.unitPrice} = ${it.total.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إجمالي الفاتورة:',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${inv.total.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('جاري إرسال الفاتورة للطابعة...', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                );
              },
              icon: const Icon(LucideIcons.printer, size: 16),
              label: const Text('طباعة الإيصال (F3)', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('فاتورة جديدة (F1)', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                context.pop(),
            const SingleActivator(LogicalKeyboardKey.f1): _resetInvoice,
            const SingleActivator(LogicalKeyboardKey.f2): _saveAndPrintInvoice,
            const SingleActivator(LogicalKeyboardKey.f5): _suspendInvoice,
          },
          child: Focus(
            autofocus: true,
            child: Row(
              children: [
                // ─── Left: Invoice Items ───────────
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Top bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(
                                LucideIcons.arrowRight,
                                color: Colors.white,
                              ),
                              tooltip: 'رجوع (Esc)',
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'نقطة البيع',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: _resetInvoice,
                              child: _buildShortcutChip('F1 فاتورة جديدة'),
                            ),
                            InkWell(
                              onTap: _saveAndPrintInvoice,
                              child: _buildShortcutChip('F2 حفظ'),
                            ),
                            InkWell(
                              onTap: _suspendInvoice,
                              child: _buildShortcutChip('F5 تعليق'),
                            ),
                            if (_suspendedCount > 0)
                              InkWell(
                                onTap: _showSuspendedInvoicesDialog,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'المعلقة ($_suspendedCount)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Barcode & Search Input Bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.white,
                        child: Row(
                          children: [
                            InkWell(
                              onTap: _showQrScannerDialog,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      LucideIcons.qrCode,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'مسح QR',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _barcodeController,
                                focusNode: _barcodeFocus,
                                textDirection: TextDirection.rtl,
                                decoration: InputDecoration(
                                  hintText:
                                      'امسح الباركود أو اكتب اسم أو كود المنتج...',
                                  prefixIcon: const Icon(LucideIcons.search,
                                      color: AppColors.textSecondary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (value) => _searchAndAddProduct(value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _searchAndAddProduct(_barcodeController.text),
                              icon: const Icon(LucideIcons.plus, size: 18),
                              label: const Text(
                                'إضافة',
                                style: TextStyle(fontFamily: 'Cairo'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Items Table Body
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              // Table header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                color: AppColors.surfaceVariant,
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '#',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'المنتج',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        'الكمية',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        'السعر',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'الخصم',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'الإجمالي',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 40),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),

                              // Items List or Empty State
                              Expanded(
                                child: _cartItems.isEmpty
                                    ? Center(
                                        child: InkWell(
                                          onTap: _showQrScannerDialog,
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                LucideIcons.scanLine,
                                                size: 54,
                                                color: AppColors.textTertiary,
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                'امسح الباركود أو الكيو ار لإضافة منتجات',
                                                style: TextStyle(
                                                  color: AppColors.textTertiary,
                                                  fontSize: 16,
                                                  fontFamily: 'Cairo',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: _cartItems.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final item = _cartItems[index];
                                          return _buildCartRow(index, item);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Right: Payment Panel ──────────
                SizedBox(
                  width: 330,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Customer Header Selector
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.user,
                                size: 20,
                                color: _selectedCustomer != null
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCustomer?.name ?? 'عميل نقدي',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_selectedCustomer != null)
                                      Text(
                                        'الرصيد: ${_selectedCustomer!.balance.toStringAsFixed(2)} ج.م',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _showCustomerSelectionDialog,
                                child: const Text(
                                  'تغيير',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Totals Summary Calculation
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildTotalRow(
                                  'المجموع', _subtotal.toStringAsFixed(2)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'الخصم',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.edit3,
                                            size: 14, color: AppColors.primary),
                                        onPressed: _showDiscountDialog,
                                        tooltip: 'إضافة خصم',
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${_overallDiscount.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildTotalRow(
                                'الإجمالي',
                                _total.toStringAsFixed(2),
                                isBold: true,
                                fontSize: 24,
                              ),
                            ],
                          ),
                        ),

                        // Payment method toggle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildPaymentButton(
                                  'نقدي',
                                  LucideIcons.banknote,
                                  _paymentMethod == 'cash',
                                  onTap: () {
                                    setState(() {
                                      _paymentMethod = 'cash';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildPaymentButton(
                                  'آجل',
                                  LucideIcons.creditCard,
                                  _paymentMethod == 'credit',
                                  onTap: () {
                                    if (_selectedCustomer == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'يرجى تحديد عميل مسجل للبيع الآجل أولاً',
                                            style: TextStyle(fontFamily: 'Cairo'),
                                          ),
                                          backgroundColor: AppColors.warning,
                                        ),
                                      );
                                      _showCustomerSelectionDialog();
                                      return;
                                    }
                                    setState(() {
                                      _paymentMethod = 'credit';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Main Action buttons
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _saveAndPrintInvoice,
                                  icon: const Icon(LucideIcons.check, size: 20),
                                  label: const Text(
                                    'حفظ وطباعة (F2)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _suspendInvoice,
                                      icon: const Icon(
                                        LucideIcons.pause,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'تعليق',
                                        style: TextStyle(fontFamily: 'Cairo'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        if (_cartItems.isNotEmpty) {
                                          _showCancelConfirmDialog();
                                        }
                                      },
                                      icon: const Icon(LucideIcons.x, size: 16),
                                      label: const Text(
                                        'إلغاء',
                                        style: TextStyle(fontFamily: 'Cairo'),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartRow(int index, PosCartItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.nameAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'كود: ${item.product.internalCode ?? "-"}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Quantity controls (- / +)
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => _updateItemQuantity(index, item.quantity - 1),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(LucideIcons.minus, size: 14),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _updateItemQuantity(index, item.quantity + 1),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(LucideIcons.plus, size: 14),
                  ),
                ),
              ],
            ),
          ),

          // Price
          SizedBox(
            width: 90,
            child: InkWell(
              onTap: () => _showEditPriceDialog(index, item),
              child: Text(
                item.unitPrice.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          // Item Discount
          SizedBox(
            width: 80,
            child: InkWell(
              onTap: () => _showEditItemDiscountDialog(index, item),
              child: Text(
                item.discount.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          // Total
          SizedBox(
            width: 100,
            child: Text(
              '${item.total.toStringAsFixed(2)} ج.م',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),

          // Remove Button
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
              onPressed: () => _removeItem(index),
              tooltip: 'حذف من الفاتورة',
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPriceDialog(int index, PosCartItem item) {
    final priceCtrl = TextEditingController(text: item.unitPrice.toString());

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'تعديل سعر ${item.product.nameAr}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: TextFormField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'السعر الجديد (ج.م)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () {
                final p = double.tryParse(priceCtrl.text) ?? item.unitPrice;
                _updateItemUnitPrice(index, p);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditItemDiscountDialog(int index, PosCartItem item) {
    final discCtrl = TextEditingController(text: item.discount.toString());

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'خصم الصنف ${item.product.nameAr}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: TextFormField(
            controller: discCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'خصم الصنف (ج.م)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () {
                final d = double.tryParse(discCtrl.text) ?? 0.0;
                _updateItemDiscount(index, d);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ الخصم', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'إلغاء الفاتورة الحالية',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'هل أنت أصلح في مسح جميع محتويات الفاتورة الحالية؟',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetInvoice();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('نعم، إلغاء الفاتورة', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutChip(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            fontSize: fontSize > 14 ? 16 : 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '$value ج.م',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontSize: fontSize,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton(
    String label,
    IconData icon,
    bool isSelected, {
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontFamily: 'Cairo')),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primarySurface : null,
        foregroundColor: isSelected
            ? AppColors.primary
            : AppColors.textSecondary,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
