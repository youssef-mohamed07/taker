import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:drift/drift.dart' as drift;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/errors/app_error_handler.dart';

class ExpensesView extends ConsumerStatefulWidget {
  const ExpensesView({super.key});

  @override
  ConsumerState<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends ConsumerState<ExpensesView> {
  DateTime? _selectedDate;
  int _tab = 0; // 0 = المصروفات، 1 = العمال والرواتب

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(treasuryTransactionsStreamProvider);
    final categories = ref.watch(expenseCategoriesStreamProvider).value ?? [];
    final categoryNames = {for (final c in categories) c.id: c.name};
    
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
                  'المصروفات والرواتب',
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                if (_tab == 0)
                  Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showCategoriesDialog(context),
                      icon: const Icon(LucideIcons.tags, size: 18),
                      label: const Text('فئات المصروفات', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                    SizedBox(width: 8.w),
                    if (can(ref, 'expenses', 'create'))
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
                  )
                else
                  if (can(ref, 'expenses', 'create'))
                    ElevatedButton.icon(
                      onPressed: () => _showWorkerFormDialog(context, null),
                      icon: const Icon(LucideIcons.userPlus),
                      label: const Text('إضافة عامل جديد', style: TextStyle(fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
              ],
            ),
            SizedBox(height: 24.h),
            
            // Tabs
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(LucideIcons.receipt, size: 16),
                  label: Text('المصروفات اليومية', style: TextStyle(fontFamily: 'Cairo')),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(LucideIcons.users, size: 16),
                  label: Text('العمال والرواتب', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (sel) => setState(() => _tab = sel.first),
            ),
            SizedBox(height: 16.h),

            if (_tab == 0) ...[
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
                              subtitle: Text(
                                '${exp.categoryId != null && categoryNames.containsKey(exp.categoryId) ? 'الفئة: ${categoryNames[exp.categoryId]} | ' : ''}${DateFormat('yyyy/MM/dd HH:mm').format(exp.createdAt)}',
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
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
            ] else ...[
              _buildWorkersTab(),
            ],
          ],
        ),
      ),
    );
  }
  
  void _showAddExpenseDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddExpenseDialog());
  }

  void _showCategoriesDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const ExpenseCategoriesDialog());
  }

  Widget _buildWorkersTab() {
    final workers = ref.watch(workersStreamProvider).value ?? [];
    final payments = ref.watch(salaryPaymentsStreamProvider).value ?? [];
    final workerNames = {for (final w in workers) w.id: w.name};
    final activeWorkers = workers.where((w) => w.isActive).toList();
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    final paidByWorker = <int, double>{};
    for (final p in payments) {
      paidByWorker[p.workerId] = (paidByWorker[p.workerId] ?? 0) + p.amount;
    }

    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workers list
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Text(
                      'سجل العمال (${activeWorkers.length} نشط من ${workers.length})',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15.sp),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: workers.isEmpty
                        ? const Center(child: Text('لا يوجد عمال مسجلون بعد — أضف عاملاً من الزر بالأعلى', style: TextStyle(fontFamily: 'Cairo')))
                        : ListView.separated(
                            itemCount: workers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final w = workers[index];
                              final paid = paidByWorker[w.id] ?? 0.0;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: w.isActive ? AppColors.primarySurface : AppColors.surfaceVariant,
                                  child: Icon(LucideIcons.user, color: w.isActive ? AppColors.primary : AppColors.textTertiary),
                                ),
                                title: Text(
                                  w.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    color: w.isActive ? AppColors.textPrimary : AppColors.textTertiary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${w.phone != null && w.phone!.isNotEmpty ? '${w.phone} | ' : ''}يومية: ${w.dailyWage.toStringAsFixed(2)} ج.م | إجمالي المقبوض: ${paid.toStringAsFixed(2)} ج.م${w.isActive ? '' : ' | غير نشط'}',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'قبض راتب',
                                      icon: const Icon(LucideIcons.banknote, color: AppColors.success, size: 18),
                                      onPressed: () => _showPaySalaryDialog(context, w),
                                    ),
                                    IconButton(
                                      tooltip: 'تعديل بيانات العامل',
                                      icon: const Icon(LucideIcons.edit, color: AppColors.primary, size: 18),
                                      onPressed: () => _showWorkerFormDialog(context, w),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16.w),
          // Totals + salary payment history
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('عدد العمال النشطين', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13.sp)),
                          Text('${activeWorkers.length}', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp, color: AppColors.primary)),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('إجمالي الرواتب المدفوعة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13.sp)),
                          Text('${totalPaid.toStringAsFixed(2)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp, color: AppColors.error)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Text('سجل دفعات الرواتب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15.sp)),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: payments.isEmpty
                              ? const Center(child: Text('لا توجد دفعات رواتب بعد', style: TextStyle(fontFamily: 'Cairo')))
                              : ListView.separated(
                                  itemCount: payments.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final p = payments[index];
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.errorLight,
                                        child: const Icon(LucideIcons.banknote, color: AppColors.error, size: 16),
                                      ),
                                      title: Text(
                                        'قبض العامل: ${workerNames[p.workerId] ?? 'عامل محذوف'}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                      ),
                                      subtitle: Text(
                                        '${DateFormat('yyyy/MM/dd HH:mm').format(p.createdAt)} | ${_methodLabel(p.paymentMethod)}${p.notes != null && p.notes!.isNotEmpty ? ' | ${p.notes}' : ''}',
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                                      ),
                                      trailing: Text(
                                        '-${p.amount.toStringAsFixed(2)} ج.م',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.error),
                                      ),
                                    );
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
        ],
      ),
    );
  }

  String _methodLabel(String method) => switch (method) {
        'card' => 'فيزا',
        'fawry' => 'فوري',
        'credit' => 'آجل',
        _ => 'نقدي',
      };

  void _showWorkerFormDialog(BuildContext context, Worker? worker) {
    final nameController = TextEditingController(text: worker?.name ?? '');
    final phoneController = TextEditingController(text: worker?.phone ?? '');
    final wageController = TextEditingController(text: worker != null ? worker.dailyWage.toStringAsFixed(2) : '');
    final notesController = TextEditingController(text: worker?.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          title: Text(
            worker == null ? 'إضافة عامل جديد' : 'تعديل بيانات العامل',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 450.w,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم العامل', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: wageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الأجر اليومي (ج.م)', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            if (worker != null)
              OutlinedButton(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  try {
                    await DbHelpers.updateWorker(
                      db,
                      id: worker.id,
                      name: worker.name,
                      phone: worker.phone,
                      dailyWage: worker.dailyWage,
                      notes: worker.notes,
                      isActive: !worker.isActive,
                      actorId: ref.read(currentUserIdProvider),
                    );
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    if (context.mounted) {
                      AppErrorHandler.showSuccessSnackBar(
                        context,
                        worker.isActive ? 'تم إيقاف العامل عن العمل' : 'تم تفعيل العامل',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppErrorHandler.showErrorSnackBar(context, 'خطأ: $e');
                    }
                  }
                },
                child: Text(
                  worker.isActive ? 'إيقاف العامل' : 'تفعيل العامل',
                  style: TextStyle(fontFamily: 'Cairo', color: worker.isActive ? AppColors.error : AppColors.success),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  AppErrorHandler.showErrorSnackBar(context, 'اسم العامل مطلوب');
                  return;
                }
                final wage = double.tryParse(wageController.text.trim()) ?? 0;
                final phone = phoneController.text.trim();
                final notes = notesController.text.trim();
                final db = ref.read(databaseProvider);
                try {
                  if (worker == null) {
                    await DbHelpers.addWorker(
                      db,
                      name: name,
                      phone: phone.isEmpty ? null : phone,
                      dailyWage: wage,
                      notes: notes.isEmpty ? null : notes,
                      actorId: ref.read(currentUserIdProvider),
                    );
                  } else {
                    await DbHelpers.updateWorker(
                      db,
                      id: worker.id,
                      name: name,
                      phone: phone.isEmpty ? null : phone,
                      dailyWage: wage,
                      notes: notes.isEmpty ? null : notes,
                      isActive: worker.isActive,
                      actorId: ref.read(currentUserIdProvider),
                    );
                  }
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    AppErrorHandler.showSuccessSnackBar(context, 'تم حفظ بيانات العامل بنجاح');
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppErrorHandler.showErrorSnackBar(context, 'خطأ: $e');
                  }
                }
              },
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaySalaryDialog(BuildContext context, Worker worker) {
    final amountController = TextEditingController(
      text: worker.dailyWage > 0 ? worker.dailyWage.toStringAsFixed(2) : '',
    );
    final notesController = TextEditingController();
    String method = 'cash';

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          title: Row(
            children: [
              const Icon(LucideIcons.banknote, color: AppColors.success),
              SizedBox(width: 8.w),
              Text(
                'قبض راتب: ${worker.name}',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 450.w,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المبلغ (ج.م)', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 16.h),
                  DropdownButtonFormField<String>(
                    initialValue: 'cash',
                    decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('نقدي — درج الكاش', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'card', child: Text('فيزا / كارت', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'fawry', child: Text('فوري', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    onChanged: (v) => method = v ?? 'cash',
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  AppErrorHandler.showErrorSnackBar(context, 'أدخل مبلغاً صحيحاً');
                  return;
                }
                final db = ref.read(databaseProvider);
                try {
                  await DbHelpers.payWorkerSalary(
                    db,
                    workerId: worker.id,
                    amount: amount,
                    userId: ref.read(currentUserIdProvider) ?? 1,
                    paymentMethod: method,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    AppErrorHandler.showSuccessSnackBar(context, 'تم تسجيل قبض الراتب بنجاح');
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppErrorHandler.showErrorSnackBar(context, 'خطأ: $e');
                  }
                }
              },
              child: const Text('تأكيد القبض', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseCategoriesDialog extends ConsumerStatefulWidget {
  const ExpenseCategoriesDialog({super.key});

  @override
  ConsumerState<ExpenseCategoriesDialog> createState() => _ExpenseCategoriesDialogState();
}

class _ExpenseCategoriesDialogState extends ConsumerState<ExpenseCategoriesDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesStreamProvider).value ?? [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('فئات المصروفات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الفئة الجديدة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) return;
                      final db = ref.read(databaseProvider);
                      await db.into(db.expenseCategories).insert(
                        ExpenseCategoriesCompanion.insert(name: name),
                      );
                      _nameController.clear();
                    },
                    child: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Flexible(
                child: categories.isEmpty
                    ? const Center(child: Text('لا توجد فئات بعد', style: TextStyle(fontFamily: 'Cairo')))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(LucideIcons.tag, color: AppColors.primary),
                            title: Text(cat.name, style: const TextStyle(fontFamily: 'Cairo')),
                            trailing: IconButton(
                              icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                              onPressed: () async {
                                final db = ref.read(databaseProvider);
                                await (db.delete(db.expenseCategories)..where((t) => t.id.equals(cat.id))).go();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
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
  final _newCategoryController = TextEditingController();
  int? _selectedCategoryId;
  bool _addingNewCategory = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesStreamProvider).value ?? [];

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
            SizedBox(height: 16.h),
            if (_addingNewCategory)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الفئة الجديدة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.check, color: AppColors.success),
                    onPressed: () async {
                      final name = _newCategoryController.text.trim();
                      if (name.isEmpty) return;
                      final db = ref.read(databaseProvider);
                      final id = await db.into(db.expenseCategories).insert(
                        ExpenseCategoriesCompanion.insert(name: name),
                      );
                      setState(() {
                        _selectedCategoryId = id;
                        _addingNewCategory = false;
                        _newCategoryController.clear();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: AppColors.error),
                    onPressed: () => setState(() => _addingNewCategory = false),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'فئة المصروف',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('بدون فئة', style: TextStyle(fontFamily: 'Cairo')),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.name, style: const TextStyle(fontFamily: 'Cairo')),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.plusCircle, color: AppColors.primary),
                    tooltip: 'فئة جديدة',
                    onPressed: () => setState(() => _addingNewCategory = true),
                  ),
                ],
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
            categoryId: drift.Value(_selectedCategoryId),
            referenceType: const drift.Value('manual_expense'),
            userId: ref.read(currentUserIdProvider) ?? 1,
          )
        );
      });

      await DbHelpers.logAudit(
        ref.read(databaseProvider),
        userId: ref.read(currentUserIdProvider) ?? 1,
        action: 'EXPENSE',
        targetTable: 'treasury_transactions',
        details: 'تسجيل مصروف: $desc بمبلغ $amount',
      );
      
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
