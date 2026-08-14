import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:audioplayers/audioplayers.dart';


import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/utils/barcode_scanner_handler.dart';

class NewPurchaseInvoiceDialog extends ConsumerStatefulWidget {
  const NewPurchaseInvoiceDialog({super.key});

  @override
  ConsumerState<NewPurchaseInvoiceDialog> createState() => _NewPurchaseInvoiceDialogState();
}

class _NewPurchaseInvoiceDialogState extends ConsumerState<NewPurchaseInvoiceDialog> {
  late final AudioPlayer _audioPlayer;

  int? selectedSupplierId;
  final List<PurchaseCartItem> cartItems = [];
  final paidController = TextEditingController(text: '0');
  late final BarcodeScannerHandler _scannerHandler;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _scannerHandler = BarcodeScannerHandler(
      onBarcodeScanned: (barcode) {
        if (mounted) {
          _processScannedBarcode(barcode);
        }
      },
    );
    _scannerHandler.start();
  }

  @override
  void dispose() {
    _scannerHandler.stop();
    _audioPlayer.dispose();
    paidController.dispose();
    super.dispose();
  }

  Future<void> _processScannedBarcode(String barcode) async {
    final db = ref.read(databaseProvider);
    final barcodeRecord = await (db.select(db.productBarcodes)..where((t) => t.barcode.equals(barcode))).getSingleOrNull();

    if (barcodeRecord != null) {
      final product = await (db.select(db.products)..where((t) => t.id.equals(barcodeRecord.productId))).getSingleOrNull();
      if (product != null) {
        _addProductToCart(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("تمت إضافة ${product.nameAr}"),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 1),
            ),
          );
        }

        return;
      }
    }
    
    // Not found
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("المنتج غير موجود! يرجى إضافته أولاً من صفحة المنتجات."),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _addProductToCart(Product p) {
    setState(() {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final db = ref.watch(databaseProvider);

    final suppliers = suppliersAsync.value ?? [];
    final products = productsAsync.value ?? [];

    final subtotal = cartItems.fold<double>(0, (sum, i) => sum + i.total);
    final paid = double.tryParse(paidController.text) ?? 0;
    final remaining = subtotal - paid;

    return AlertDialog(
                title: Row(
                  children: [
                    Icon(LucideIcons.shoppingBag, color: AppColors.primary),
                    SizedBox(width: 8.w),
                    Text('فاتورة شراء جديدة من مورد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SizedBox(
                  width: 700.w,
                  height: 500.h,
                  child: Column(
                    children: [
                      // Supplier selection
                      Row(
                        children: [
                          Text('اختر المورد:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedSupplierId,
                              hint: Text('حدد المورد', style: TextStyle(fontFamily: 'Cairo')),
                              items: suppliers.map((s) {
                                return DropdownMenuItem<int>(
                                  value: s.id,
                                  child: Text(s.name, style: TextStyle(fontFamily: 'Cairo')),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => selectedSupplierId = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Add Item controls
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<Product>(
                              hint: Text('اختر المنتج للإضافة للمشتريات', style: TextStyle(fontFamily: 'Cairo')),
                              items: products.map((p) {
                                return DropdownMenuItem<Product>(
                                  value: p,
                                  child: Text('${p.nameAr} (سعر الشراء الحالي: ${p.purchasePrice})', style: TextStyle(fontFamily: 'Cairo')),
                                );
                              }).toList(),
                              onChanged: (p) {
                                if (p != null) _addProductToCart(p);
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Cart Items Table
                      Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: cartItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'قم باختيار منتجات لإضافتها إلى فاتورة الشراء',
                                    style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Cairo'),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: cartItems.length,
                                  separatorBuilder: (_, __) => Divider(height: 1.h),
                                  itemBuilder: (context, index) {
                                    final item = cartItems[index];
                                    return CartItemRow(
                                      item: item,
                                      onChanged: (updatedItem) {
                                        setState(() {
                                          cartItems[index] = updatedItem;
                                        });
                                      },
                                      onRemove: () {
                                        setState(() {
                                          cartItems.removeAt(index);
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Totals & Paid Amount
                      Row(
                        children: [
                          Text('الإجمالي: ${subtotal.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15.sp)),
                          const Spacer(),
                          Text('المدفوع: ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          SizedBox(
                            width: 120.w,
                            child: TextField(
                              controller: paidController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: 'ج.م',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Text('المتبقي: ${remaining.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.error)),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
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
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم حفظ فاتورة الشراء رقم $invoiceId بنجاح وتحديث المخزون!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                    child: Text('حفظ الفاتورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
  }
}

class FastAddProductDialog extends ConsumerStatefulWidget {
  final String scannedBarcode;
  final Function(Product) onProductAdded;

  const FastAddProductDialog({
    super.key,
    required this.scannedBarcode,
    required this.onProductAdded,
  });

  @override
  ConsumerState<FastAddProductDialog> createState() => _FastAddProductDialogState();
}

class _FastAddProductDialogState extends ConsumerState<FastAddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _retailPriceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _retailPriceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      
      final productId = await DbHelpers.addProduct(
        db,
        nameAr: _nameController.text.trim(),
        barcode: widget.scannedBarcode,
        purchasePrice: double.tryParse(_purchasePriceController.text.trim()) ?? 0,
        retailPrice: double.tryParse(_retailPriceController.text.trim()) ?? 0,
        initialQuantity: double.tryParse(_qtyController.text.trim()) ?? 1,
      );
      
      final product = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
      
      if (mounted) {
        Navigator.pop(context);
        widget.onProductAdded(product);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إضافة منتج جديد سريع', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('الباركود: ${widget.scannedBarcode}', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              const Divider(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _retailPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سعر البيع', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية الافتتاحية', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('حفظ وإضافة للفاتورة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}


class CartItemRow extends StatefulWidget {
  final PurchaseCartItem item;
  final Function(PurchaseCartItem) onChanged;
  final VoidCallback onRemove;

  const CartItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends State<CartItemRow> {
  late TextEditingController _qtyController;
  late TextEditingController _priceController;



  @override
  void didUpdateWidget(CartItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _qtyController.text = widget.item.quantity.toString();
    }
    if (oldWidget.item.purchasePrice != widget.item.purchasePrice) {
      _priceController.text = widget.item.purchasePrice.toString();
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.item.quantity.toString());
    _priceController = TextEditingController(text: widget.item.purchasePrice.toString());
    
  }

  void _updateItem() {
    final q = double.tryParse(_qtyController.text) ?? widget.item.quantity;
    final p = double.tryParse(_priceController.text) ?? widget.item.purchasePrice;
    
    if (q != widget.item.quantity || p != widget.item.purchasePrice ) {
      widget.onChanged(PurchaseCartItem(
        product: widget.item.product,
        quantity: q,
        purchasePrice: p,
        
        
      ));
    }
  }

  Future<void> _pickExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (date != null) {
      setState(() => _expiryDate = date);
      _updateItem();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              widget.item.product.nameAr,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _updateItem(),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكمية',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _updateItem(),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _pickExpiryDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _expiryDate == null ? 'الصلاحية (اختياري)' : DateFormat('yyyy/MM/dd').format(_expiryDate!),
                      style: const TextStyle(fontSize: 12, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'الإجمالي: ${widget.item.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
