import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';

class RechargeFawryDialog extends ConsumerStatefulWidget {
  const RechargeFawryDialog({super.key});

  @override
  ConsumerState<RechargeFawryDialog> createState() => _RechargeFawryDialogState();
}

class _RechargeFawryDialogState extends ConsumerState<RechargeFawryDialog> {
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(amountCtrl.text);
    
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من الصفر')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final db = ref.read(databaseProvider);
      final currentUser = ref.read(currentUserProvider);
      await DbHelpers.rechargeFawryMachine(
        db,
        amount: amount,
        description: descCtrl.text,
        userId: currentUser?.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تزويد رصيد الماكينة (شحن)', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيتم تسجيل مبلغ الشحن كمصروف من الخزنة الرئيسية وإضافته كرصيد رقمي لماكينة فوري.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'مبلغ الشحن',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('تأكيد الشحن', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
