import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';

class ExpirationAlertsView extends ConsumerStatefulWidget {
  const ExpirationAlertsView({super.key});

  @override
  ConsumerState<ExpirationAlertsView> createState() => _ExpirationAlertsViewState();
}

class _ExpirationAlertsViewState extends ConsumerState<ExpirationAlertsView> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final next90Days = now.add(const Duration(days: 90));

    // Get batches expiring within 90 days that have quantity > 0
    final query = db.select(db.productBatches).join([
      drift.innerJoin(db.products, db.products.id.equalsExp(db.productBatches.productId)),
    ])
      ..where(db.productBatches.quantity.isBiggerThanValue(0))
      ..where(db.productBatches.expiryDate.isNotNull())
      ..where(db.productBatches.expiryDate.isSmallerOrEqualValue(next90Days))
      ..orderBy([drift.OrderingTerm.asc(db.productBatches.expiryDate)]);

    final results = await query.get();

    final alerts = results.map((row) {
      final batch = row.readTable(db.productBatches);
      final product = row.readTable(db.products);
      final daysLeft = batch.expiryDate!.difference(now).inDays;

      return {
        'product': product.nameAr,
        'quantity': batch.quantity,
        'expiryDate': batch.expiryDate!,
        'daysLeft': daysLeft,
      };
    }).toList();

    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تنبيهات الصلاحية',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'المنتجات التي ستنتهي صلاحيتها خلال 90 يوماً',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14.sp,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw),
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadAlerts();
                  },
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _alerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.checkCircle, size: 48, color: AppColors.success),
                                SizedBox(height: 12.h),
                                Text('لا توجد منتجات قريبة من الانتهاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _alerts.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final alert = _alerts[index];
                              final int daysLeft = alert['daysLeft'];
                              
                              Color statusColor;
                              if (daysLeft < 0) {
                                statusColor = AppColors.error; // Expired
                              } else if (daysLeft <= 30) {
                                statusColor = AppColors.warning; // Critical
                              } else {
                                statusColor = Colors.orangeAccent; // Soon
                              }

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(alpha: 0.1),
                                  child: Icon(
                                    daysLeft < 0 ? LucideIcons.alertOctagon : LucideIcons.alertTriangle,
                                    color: statusColor,
                                  ),
                                ),
                                title: Text(alert['product'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                subtitle: Text(
                                  daysLeft < 0 ? 'منتهي الصلاحية منذ ${-daysLeft} يوماً' : 'ينتهي بعد $daysLeft يوماً',
                                  style: TextStyle(color: statusColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('الكمية المتبقية: ${alert['quantity']}', style: const TextStyle(fontFamily: 'Cairo')),
                                    Text(
                                      DateFormat('yyyy/MM/dd').format(alert['expiryDate']),
                                      style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12),
                                    ),
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
}
