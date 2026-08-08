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

class ExpensesView extends ConsumerStatefulWidget {
  const ExpensesView({super.key});

  @override
  ConsumerState<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends ConsumerState<ExpensesView> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(treasuryTransactionsStreamProvider);
    
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
                  'المصروفات اليومية',
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddExpenseDialog(context),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('تسجيل مصروف جديد', style: TextStyle(fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            
            // Filter
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  icon: const Icon(LucideIcons.calendar, size: 18),
                  label: Text(_selectedDate == null ? 'تصفية بالتاريخ' : DateFormat('yyyy/MM/dd').format(_selectedDate!)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                if (_selectedDate != null)
                  Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: IconButton(
                      icon: const Icon(LucideIcons.xCircle, color: AppColors.error),
                      onPressed: () => setState(() => _selectedDate = null),
                    ),
                  )
              ],
            ),
            SizedBox(height: 24.h),
            
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  final expenses = transactions.where((t) {
                    if (t.type != 'EXPENSE') return false;
                    if (t.referenceType != 'manual_expense') return false;
                    
                    if (_selectedDate != null) {
                      return t.createdAt.year == _selectedDate!.year &&
                             t.createdAt.month == _selectedDate!.month &&
                             t.createdAt.day == _selectedDate!.day;
                    }
                    return true;
                  }).toList();

                  expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: expenses.isEmpty
                      ? const Center(child: Text('لا توجد مصروفات مسجلة', style: TextStyle(fontFamily: 'Cairo')))
                      : ListView.separated(
                          itemCount: expenses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final exp = expenses[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.errorLight,
                                child: const Icon(LucideIcons.arrowDownRight, color: AppColors.error),
                              ),
                              title: Text(exp.description ?? 'مصروف', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(exp.createdAt), style: const TextStyle(fontFamily: 'Cairo')),
                              trailing: Text('${exp.amount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.error, fontSize: 16)),
                            );
                          },
                        ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAddExpenseDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddExpenseDialog());
  }
}

class AddExpenseDialog extends ConsumerStatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل مصروف جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (ج.م)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'البيان / الوصف (مثال: فاتورة كهرباء)',
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
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _isLoading ? null : _saveExpense,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('حفظ', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amountController.text);
    final desc = _descController.text.trim();
    
    if (amount == null || amount <= 0 || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء إدخال المبلغ والوصف بشكل صحيح')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      
      await db.transaction(() async {
        final activeShift = await DbHelpers.getActiveShift(db);
        
        final treasuries = await db.select(db.treasury).get();
        if (treasuries.isEmpty) throw Exception('لا يوجد خزانة مسجلة');
        final mainTreasury = treasuries.first;
        
        if (mainTreasury.currentBalance < amount) {
          throw Exception('الرصيد في الخزينة لا يكفي لهذا المصروف (${mainTreasury.currentBalance} ج.م فقط)');
        }
        
        await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
            .write(TreasuryCompanion(currentBalance: drift.Value(mainTreasury.currentBalance - amount)));
            
        await db.into(db.treasuryTransactions).insert(
          TreasuryTransactionsCompanion.insert(
            treasuryId: mainTreasury.id,
            shiftId: drift.Value(activeShift?.id),
            type: 'EXPENSE',
            amount: amount,
            description: drift.Value(desc),
            referenceType: const drift.Value('manual_expense'),
            userId: 1,
          )
        );
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل المصروف بنجاح')));
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
}
