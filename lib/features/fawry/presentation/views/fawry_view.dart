import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/auth/auth_service.dart';
import 'package:intl/intl.dart';

import '../dialogs/execute_fawry_service_dialog.dart';
import '../dialogs/recharge_fawry_dialog.dart';

class FawryView extends ConsumerStatefulWidget {
  const FawryView({super.key});

  @override
  ConsumerState<FawryView> createState() => _FawryViewState();
}

class _FawryViewState extends ConsumerState<FawryView> {
  void _showExecuteDialog() {
    showDialog(
      context: context,
      builder: (context) => const ExecuteFawryServiceDialog(),
    );
  }

  void _showRechargeDialog() {
    showDialog(
      context: context,
      builder: (context) => const RechargeFawryDialog(),
    );
  }

  Future<void> _deleteTransaction(FawryTransaction tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red)),
        content: const Text('هل أنت متأكد من حذف هذه العملية؟ سيتم استرجاع الرصيد وتعديل الدرج.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(databaseProvider);
      await DbHelpers.deleteFawryTransaction(db, tx.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف العملية بنجاح')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إدارة ماكينة فوري',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (can(ref, 'fawry', 'create'))
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showExecuteDialog,
                      icon: const Icon(LucideIcons.zap),
                      label: const Text('تنفيذ خدمة لعميل'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showRechargeDialog,
                      icon: const Icon(LucideIcons.batteryCharging),
                      label: const Text('شحن رصيد الماكينة'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Cards
          StreamBuilder<FawryMachineData>(
            stream: DbHelpers.watchFawryBalance(db),
            builder: (context, snapshot) {
              final data = snapshot.data;
              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'الرصيد الرقمي للماكينة',
                      amount: data?.digitalBalance ?? 0,
                      icon: LucideIcons.smartphone,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'الكاش المحصل بالدرج',
                      amount: data?.cashCollected ?? 0,
                      icon: LucideIcons.banknote,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'إجمالي الأرباح',
                      amount: data?.totalProfits ?? 0,
                      icon: LucideIcons.trendingUp,
                      color: Colors.purple,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Transactions Table
          Expanded(
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'سجل عمليات فوري',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<List<FawryTransaction>>(
                        stream: DbHelpers.watchFawryTransactions(db),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final txs = snapshot.data!;
                          if (txs.isEmpty) {
                            return const Center(child: Text('لا توجد عمليات مسجلة بعد'));
                          }
                          return DataTable2(
                            headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 800,
                            columns: const [
                              DataColumn2(label: Text('رقم العملية'), size: ColumnSize.S),
                              DataColumn2(label: Text('التاريخ'), size: ColumnSize.L),
                              DataColumn2(label: Text('نوع العملية'), size: ColumnSize.M),
                              DataColumn2(label: Text('المبلغ الرقمي'), size: ColumnSize.M, numeric: true),
                              DataColumn2(label: Text('الكاش من العميل'), size: ColumnSize.M, numeric: true),
                              DataColumn2(label: Text('الربح'), size: ColumnSize.S, numeric: true),
                              DataColumn2(label: Text('وصف'), size: ColumnSize.L),
                              DataColumn2(label: Text('إجراءات'), size: ColumnSize.S),
                            ],
                            rows: txs.map((tx) {
                              final isService = tx.type == 'service';
                              return DataRow(cells: [
                                DataCell(Text('#${tx.id}')),
                                DataCell(Text(DateFormat('yyyy/MM/dd hh:mm a').format(tx.createdAt))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isService ? Colors.orange[100] : Colors.blue[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isService ? 'خدمة (خصم)' : 'شحن (إضافة)',
                                      style: TextStyle(
                                        color: isService ? Colors.orange[800] : Colors.blue[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text('ج.م ${tx.amount.abs().toStringAsFixed(2)}', style: TextStyle(color: isService ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
                                DataCell(Text(isService ? 'ج.م ${(tx.customerPaid ?? 0).toStringAsFixed(2)}' : '-')),
                                DataCell(Text(isService ? 'ج.م ${tx.profit.toStringAsFixed(2)}' : '-')),
                                DataCell(Text(tx.description ?? '-')),
                                DataCell(
                                  can(ref, 'fawry', 'delete')
                                      ? IconButton(
                                          icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                                          onPressed: () => _deleteTransaction(tx),
                                          tooltip: 'حذف العملية وإلغاء تأثيرها',
                                        )
                                      : const SizedBox(),
                                ),
                              ]);
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required double amount, required IconData icon, required Color color}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'ج.م ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
