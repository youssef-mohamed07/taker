import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';

class ExecuteFawryServiceDialog extends ConsumerStatefulWidget {
  const ExecuteFawryServiceDialog({super.key});

  @override
  ConsumerState<ExecuteFawryServiceDialog> createState() => _ExecuteFawryServiceDialogState();
}

class _ExecuteFawryServiceDialogState extends ConsumerState<ExecuteFawryServiceDialog> {
  final deductedCtrl = TextEditingController();
  final paidCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    deductedCtrl.dispose();
    paidCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final deducted = double.tryParse(deductedCtrl.text);
    final paid = double.tryParse(paidCtrl.text);
    
    if (deducted == null || paid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبالغ صحيحة')),
      );
      return;
    }
    
    if (paid < deducted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المبلغ المدفوع يجب أن يكون أكبر من أو يساوي المخصوم')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final db = ref.read(databaseProvider);
      final currentUser = ref.read(currentUserProvider);
      await DbHelpers.executeFawryService(
        db,
        customerPaid: paid,
        machineDeducted: deducted,
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
      title: const Text('تنفيذ خدمة فوري', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: deductedCtrl,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المخصوم من الماكينة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money_off),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: paidCtrl,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المدفوع من العميل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'وصف الخدمة (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
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
              : const Text('تأكيد الخدمة', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
