import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/db_helpers.dart';

class ProductFormView extends ConsumerStatefulWidget {
  const ProductFormView({super.key});

  @override
  ConsumerState<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends ConsumerState<ProductFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _buyPriceController = TextEditingController(text: '0');
  final _sellPriceController = TextEditingController(text: '0');
  final _stockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '5');
  final _unitController = TextEditingController(text: 'قطعة');

  int? _selectedCategoryId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      await DbHelpers.addProduct(
        db,
        nameAr: _nameController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        categoryId: _selectedCategoryId,
        purchasePrice: double.tryParse(_buyPriceController.text.trim()) ?? 0.0,
        retailPrice: double.tryParse(_sellPriceController.text.trim()) ?? 0.0,
        wholesalePrice:
            double.tryParse(_sellPriceController.text.trim()) ?? 0.0,
        initialQuantity: double.tryParse(_stockController.text.trim()) ?? 0.0,
        minQuantity: double.tryParse(_minStockController.text.trim()) ?? 5.0,
        userId: 1,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ الصنف بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء الحفظ: $e',
              style: TextStyle(fontFamily: 'Cairo'),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'إضافة صنف جديد',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowRight),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بيانات الصنف',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الصنف *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'الرجاء إدخال اسم الصنف'
                              : null,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _barcodeController,
                          decoration: const InputDecoration(
                            labelText: 'الباركود',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(LucideIcons.qrCode, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: categoriesAsync.when(
                          data: (categories) => DropdownButtonFormField<int>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'الفئة / القسم',
                              border: OutlineInputBorder(),
                            ),
                            items: categories
                                .map(
                                  (cat) => DropdownMenuItem<int>(
                                    value: cat.id,
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedCategoryId = val),
                          ),
                          loading: () => const CircularProgressIndicator(),
                          error: (_, __) => SizedBox(),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextFormField(
                          controller: _unitController,
                          decoration: const InputDecoration(
                            labelText: 'وحدة القياس',
                            border: OutlineInputBorder(),
                            hintText: 'قطعة / كيلو / كرتونة',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'الأسعار والكمية',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _buyPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سعر الشراء (ج.م) *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              val == null || double.tryParse(val) == null
                              ? 'سعر غير صحيح'
                              : null,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextFormField(
                          controller: _sellPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سعر البيع (ج.م) *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              val == null || double.tryParse(val) == null
                              ? 'سعر غير صحيح'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الرصيد الافتتاحي *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              val == null || double.tryParse(val) == null
                              ? 'كمية غير صحيحة'
                              : null,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextFormField(
                          controller: _minStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'حد إنذار نقص النواقص',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        child: Text(
                          'إلغاء',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveProduct,
                        icon: Icon(LucideIcons.save, size: 18),
                        label: _isLoading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'حفظ الصنف',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16.sp,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.w,
                            vertical: 14.h,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
