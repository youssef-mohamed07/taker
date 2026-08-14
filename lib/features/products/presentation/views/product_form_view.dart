import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'products_view.dart';

class ProductFormView extends StatelessWidget {
  final int? productId;
  const ProductFormView({super.key, this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AddProductDialog(),
      ),
    );
  }
}
