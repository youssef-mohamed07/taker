import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/errors/app_error_handler.dart';

class ShiftsView extends ConsumerStatefulWidget {
  const ShiftsView({super.key});

  @override
  ConsumerState<ShiftsView> createState() => _ShiftsViewState();
}

class _ShiftsViewState extends ConsumerState<ShiftsView> {
  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(shiftsStreamProvider);
    final txsAsync = ref.watch(treasuryTransactionsStreamProvider);
    final db = ref.watch(databaseProvider);

    final shifts = shiftsAsync.value ?? [];
    final openShift = shifts.where((s) => s.status == 'open').firstOrNull;
    final allTxs = txsAsync.value ?? [];

    double shiftIncome = 0.0;
    double shiftExpense = 0.0;
    double expectedTreasury = 0.0;

    if (openShift != null) {
      final shiftTxs = allTxs.where((tx) =>
          tx.shiftId == openShift.id ||
          (tx.createdAt.isAfter(openShift.openedAt) && tx.shiftId == null));

      for (final tx in shiftTxs) {
        if (tx.type == 'INCOME' || tx.type == 'DEPOSIT') {
          shiftIncome += tx.amount;
        } else if (tx.type == 'EXPENSE' || tx.type == 'WITHDRAWAL') {
          shiftExpense += tx.amount;
        }
      }
      expectedTreasury = openShift.openingBalance + shiftIncome - shiftExpense;
    }

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
                        'إدارة الشيفتات والورديات',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'متابعة النقدية عند استلام وتسليم الخزنة لكل وردية',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                if (openShift == null)
                  ElevatedButton.icon(
                    onPressed: () => _showOpenShiftDialog(context, db),
                    icon: const Icon(LucideIcons.play, size: 18),
                    label: const Text('فتح شيفت جديد',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _showCloseShiftDialog(context, db, openShift, expectedTreasury),
                    icon: const Icon(LucideIcons.square, size: 18),
                    label: const Text('غلق الشيفت الحالي',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Active Shift Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: openShift != null ? AppColors.success : AppColors.border,
                  width: openShift != null ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (openShift != null ? AppColors.success : AppColors.warning)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          openShift != null ? LucideIcons.checkCircle : LucideIcons.clock,
                          color: openShift != null ? AppColors.success : AppColors.warning,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              openShift != null
                                  ? 'حالة الوردية: شيفت نشط حالياً (#${openShift.id})'
                                  : 'حالة الوردية: لا يوجد شيفت مفتوح',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              openShift != null
                                  ? 'تم الفتح بتاريخ: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(openShift.openedAt)}'
                                  : 'اضغط على زر "فتح شيفت جديد" لبدء الوردية وتحديد رصيد البداية بالخزنة',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (openShift != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            title: 'الرصيد الافتتاحي',
                            value: '${openShift.openingBalance.toStringAsFixed(2)} ج.م',
                            icon: LucideIcons.wallet,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            title: 'مقبوضات الشيفت (+)',
                            value: '${shiftIncome.toStringAsFixed(2)} ج.م',
                            icon: LucideIcons.arrowDownLeft,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            title: 'مصروفات الشيفت (-)',
                            value: '${shiftExpense.toStringAsFixed(2)} ج.م',
                            icon: LucideIcons.arrowUpRight,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            title: 'المتوقع بالخزنة الآن',
                            value: '${expectedTreasury.toStringAsFixed(2)} ج.م',
                            icon: LucideIcons.badgeCheck,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'سجل الشيفتات والورديات السابقة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Shifts List Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: shifts.isEmpty
                    ? const Center(
                        child: Text(
                          'لا يوجد سجل شيفتات بعد',
                          style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Cairo'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: shifts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final s = shifts[index];
                          final isOpen = s.status == 'open';

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isOpen ? AppColors.success : AppColors.primary)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isOpen ? LucideIcons.play : LucideIcons.checkCheck,
                                color: isOpen ? AppColors.success : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'شيفت #${s.id}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOpen
                                        ? AppColors.successLight
                                        : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOpen ? 'مفتوح' : 'مغلق',
                                    style: TextStyle(
                                      color: isOpen
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'الفترة: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(s.openedAt)} '
                              '${s.closedAt != null ? '- ${intl.DateFormat('HH:mm').format(s.closedAt!)}' : ''}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Cairo',
                                  fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'الافتتاحي: ${s.openingBalance.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                ),
                                if (s.closingBalance != null) ...[
                                  Text(
                                    'الإغلاق: ${s.closingBalance!.toStringAsFixed(2)} ج.م (المتوقع: ${(s.expectedBalance ?? 0).toStringAsFixed(2)})',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontFamily: 'Cairo'),
                                  ),
                                  if ((s.difference ?? 0) != 0)
                                    Text(
                                      'الفارق (عجز/زيادة): ${s.difference! > 0 ? '+' : ''}${s.difference!.toStringAsFixed(2)} ج.م',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: s.difference! < 0
                                            ? AppColors.error
                                            : AppColors.success,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenShiftDialog(BuildContext context, AppDatabase db) {
    final balanceController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(LucideIcons.play, color: AppColors.success),
                SizedBox(width: 8),
                Text('فتح وردية جديدة',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ الافتتاحي بالخزنة (ج.م)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: () async {
                  final opening = double.tryParse(balanceController.text) ?? 0;
                  try {
                    await DbHelpers.openShift(db, openingBalance: opening, userId: 1);
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      AppErrorHandler.showSuccessSnackBar(context, 'تم فتح الوردية بنجاح!');
                    }
                  } catch (e) {
                    if (dialogCtx.mounted) {
                      AppErrorHandler.showErrorDialog(context, e, title: 'خطأ في فتح الوردية');
                    }
                  }
                },
                child: const Text('فتح الشيفت',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCloseShiftDialog(
      BuildContext context, AppDatabase db, Shift shift, double expectedBalance) {
    final closingController = TextEditingController(text: expectedBalance.toStringAsFixed(2));
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(LucideIcons.square, color: AppColors.error),
                SizedBox(width: 8),
                Text('إغلاق الوردية الحالية',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الرصيد الافتتاحي:', style: TextStyle(fontFamily: 'Cairo')),
                            Text('${shift.openingBalance.toStringAsFixed(2)} ج.م',
                                style: const TextStyle(
                                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('المبلغ المتوقع توفره بالخزنة:',
                                style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
                            Text('${expectedBalance.toStringAsFixed(2)} ج.م',
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: closingController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الفعلي الموجود بالخزنة عند الإغلاق (ج.م)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الإغلاق (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () async {
                  try {
                    final closing = double.tryParse(closingController.text) ?? expectedBalance;
                    await DbHelpers.closeShift(
                      db,
                      shiftId: shift.id,
                      closingBalance: closing,
                      notes: notesController.text.isNotEmpty ? notesController.text : null,
                    );

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      AppErrorHandler.showSuccessSnackBar(
                          context, 'تم إغلاق الشيفت وتسوية الحسابات بنجاح!');
                    }
                  } catch (e) {
                    if (dialogCtx.mounted) {
                      AppErrorHandler.showErrorDialog(context, e, title: 'خطأ في إغلاق الوردية');
                    }
                  }
                },
                child: const Text(
                  'تأكيد الإغلاق',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}










