import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/di/providers.dart';

class NewPurchaseReturnDialog extends ConsumerStatefulWidget {
  final int? invoiceId;
  const NewPurchaseReturnDialog({super.key, this.invoiceId});

  @override
  ConsumerState<NewPurchaseReturnDialog> createState() => _NewPurchaseReturnDialogState();
}

class _NewPurchaseReturnDialogState extends ConsumerState<NewPurchaseReturnDialog> {
  final Map<Product, double> _returnItems = {};
  int? _selectedCustomerId;
  String _paymentMethod = 'cash';
  bool _isLoading = false;
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.invoiceId != null) {
      _loadInvoiceData();
    }
  }

  Future<void> _loadInvoiceData() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      
      // Load invoice
      final invoice = await (db.select(db.purchaseInvoices)..where((t) => t.id.equals(widget.invoiceId!))).getSingle();
      _selectedCustomerId = invoice.supplierId;
      _paymentMethod = invoice.paymentMethod;

      // Load items
      final query = db.select(db.purchaseItems).join([
        drift.innerJoin(db.products, db.products.id.equalsExp(db.purchaseItems.productId)),
      ])..where(db.purchaseItems.purchaseInvoiceId.equals(widget.invoiceId!));
      
      final results = await query.get();
      for (final row in results) {
        final item = row.readTable(db.purchaseItems);
        final product = row.readTable(db.products);
        _returnItems[product] = item.quantity;
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في تحميل بيانات الفاتورة: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalAmount {
    return _returnItems.entries.fold(0.0, (sum, item) => sum + (item.key.purchasePrice * item.value));
  }

  void _addProduct(Product product) {
    setState(() {
      _returnItems[product] = (_returnItems[product] ?? 0.0) + 1.0;
    });
  }

  Future<void> _submit() async {
    if (_returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إضافة أصناف للمرتجع')));
      return;
    }
    if (_paymentMethod == 'credit' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب اختيار المورد في حالة الآجل')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      
      final itemsToReturn = _returnItems.entries.map((e) {
        return PurchaseReturnItemsCompanion.insert(
          returnId: 0, // Will be set in db_helpers
          productId: e.key.id,
          quantity: e.value,
          unitPrice: e.key.purchasePrice,
          total: e.key.purchasePrice * e.value,
        );
      }).toList();

      await DbHelpers.processPurchaseReturn(
        db,
        invoiceId: widget.invoiceId,
        supplierId: _selectedCustomerId,
        totalAmount: _totalAmount,
        paymentMethod: _paymentMethod,
        items: itemsToReturn.cast<PurchaseReturnItemsCompanion>(),
        userId: 1, // Admin
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل مرتجع المشتريات بنجاح'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(suppliersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: AppColors.background,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.invoiceId != null ? 'إرجاع أصناف من فاتورة مشتريات #${widget.invoiceId}' : 'مرتجع مشتريات جديد',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side (actually on the Right in RTL): Cart & Details
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.all(24.w),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppColors.border),
                                color: AppColors.background,
                              ),
                              child: _returnItems.isEmpty
                                  ? Center(child: Text('لم يتم إضافة أصناف للمرتجع', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)))
                                  : ListView(
                                      padding: EdgeInsets.all(8.w),
                                      children: _returnItems.entries.map((e) {
                                        final product = e.key;
                                        final qty = e.value;
                                        return Card(
                                          margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8.r),
                                            side: const BorderSide(color: AppColors.border),
                                          ),
                                          child: ListTile(
                                            title: Text(product.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                            subtitle: Text('${product.purchasePrice} ج.م × $qty = ${product.purchasePrice * qty} ج.م', style: TextStyle(color: AppColors.primary, fontFamily: 'Cairo')),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(LucideIcons.minusCircle, color: AppColors.error),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (qty > 1) {
                                                        _returnItems[product] = qty - 1;
                                                      } else {
                                                        _returnItems.remove(product);
                                                      }
                                                    });
                                                  },
                                                ),
                                                Text(qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                IconButton(
                                                  icon: const Icon(LucideIcons.plusCircle, color: AppColors.success),
                                                  onPressed: () => _addProduct(product),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ),
                          // Details Form
                          Container(
                            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('الإجمالي المسترد:', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.primary)),
                                        Text('${_totalAmount.toStringAsFixed(2)} ج.م', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.primary)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  customersAsync.when(
                                    data: (customers) => DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      value: _selectedCustomerId,
                                      decoration: InputDecoration(
                                        labelText: 'المورد', 
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                      ),
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text('بدون عميل (نقدي)')),
                                        ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                      ],
                                      onChanged: (val) => setState(() => _selectedCustomerId = val),
                                    ),
                                    loading: () => const CircularProgressIndicator(),
                                    error: (e, _) => const Text('خطأ في تحميل العملاء'),
                                  ),
                                  SizedBox(height: 12.h),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _paymentMethod,
                                    decoration: InputDecoration(
                                      labelText: 'طريقة الدفع/الاسترداد', 
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'cash', child: Text('كاش (استرداد نقدي)')),
                                      DropdownMenuItem(value: 'credit', child: Text('آجل (خصم من مديونية المورد)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _paymentMethod = val);
                                    },
                                  ),
                                  SizedBox(height: 12.h),
                                  TextFormField(
                                    controller: _notesController,
                                    decoration: InputDecoration(
                                      labelText: 'ملاحظات', 
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                  // Vertical Divider
                  Container(width: 1, color: AppColors.border),
                  // Right Side (actually on the Left in RTL): Products Selection
                  Expanded(
                    flex: 6,
                    child: Container(
                      color: AppColors.background,
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('اختر الأصناف المسترجعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18.sp)),
                          SizedBox(height: 16.h),
                          Expanded(
                            child: productsAsync.when(
                              data: (products) => GridView.builder(
                                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 180.w,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 16.w,
                                  mainAxisSpacing: 16.h,
                                ),
                                itemCount: products.length,
                                itemBuilder: (context, index) {
                                  final product = products[index];
                                  return InkWell(
                                    onTap: () => _addProduct(product),
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: AppColors.border),
                                        borderRadius: BorderRadius.circular(12.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      padding: EdgeInsets.all(12.w),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(12.w),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primaryLight,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(LucideIcons.box, color: AppColors.primary, size: 28),
                                          ),
                                          SizedBox(height: 12.h),
                                          Text(
                                            product.nameAr, 
                                            textAlign: TextAlign.center, 
                                            maxLines: 2, 
                                            overflow: TextOverflow.ellipsis, 
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: 'Cairo', height: 1.2)
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius: BorderRadius.circular(20.r),
                                            ),
                                            child: Text(
                                              '${product.purchasePrice} ج.م', 
                                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.sp)
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => const Center(child: Text('خطأ في تحميل المنتجات')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h)),
                    child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', fontSize: 16.sp)),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(LucideIcons.checkCircle, size: 18),
                    label: Text('اعتماد المرتجع', style: TextStyle(fontFamily: 'Cairo', fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, 
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
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
}
