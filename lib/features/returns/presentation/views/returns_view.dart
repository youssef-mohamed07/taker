import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:drift/drift.dart' as drift;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/providers.dart';
import 'new_sales_return_dialog.dart';
import 'new_purchase_return_dialog.dart';

// Stream Providers for Returns
final salesReturnsProvider = StreamProvider<List<SalesReturn>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.salesReturns)..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])).watch();
});

final purchaseReturnsProvider = StreamProvider<List<PurchaseReturn>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.purchaseReturns)..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])).watch();
});

class ReturnsView extends ConsumerStatefulWidget {
  const ReturnsView({super.key});

  @override
  ConsumerState<ReturnsView> createState() => _ReturnsViewState();
}

class _ReturnsViewState extends ConsumerState<ReturnsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showReturnDetails(BuildContext context, {required String returnNumber, required String title, required int returnId, required bool isSales}) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            child: Container(
              width: 550.w,
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: isSales ? AppColors.errorLight : AppColors.successLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSales ? LucideIcons.rotateCcw : LucideIcons.rotateCw,
                              color: isSales ? AppColors.error : AppColors.success,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            '$title #$returnNumber',
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchReturnItems(returnId, isSales),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('لا توجد تفاصيل أصناف لهذا المرتجع', style: TextStyle(fontFamily: 'Cairo')));
                      }
                      final items = snapshot.data!;
                      return Container(
                        constraints: BoxConstraints(maxHeight: 300.h),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              subtitle: Text('${item['price']} ج.م × ${item['quantity']}', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13.sp)),
                              trailing: Text(
                                '${item['total']} ج.م',
                                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isSales ? AppColors.error : AppColors.success, fontSize: 15.sp),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 24.h),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', fontSize: 15.sp)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchReturnItems(int returnId, bool isSales) async {
    final db = ref.read(databaseProvider);
    if (isSales) {
      final query = db.select(db.salesReturnItems).join([
        drift.innerJoin(db.products, db.products.id.equalsExp(db.salesReturnItems.productId)),
      ])..where(db.salesReturnItems.returnId.equals(returnId));
      final results = await query.get();
      return results.map((row) {
        final item = row.readTable(db.salesReturnItems);
        final product = row.readTable(db.products);
        return {
          'name': product.nameAr,
          'price': item.unitPrice,
          'quantity': item.quantity,
          'total': item.total,
        };
      }).toList();
    } else {
      final query = db.select(db.purchaseReturnItems).join([
        drift.innerJoin(db.products, db.products.id.equalsExp(db.purchaseReturnItems.productId)),
      ])..where(db.purchaseReturnItems.returnId.equals(returnId));
      final results = await query.get();
      return results.map((row) {
        final item = row.readTable(db.purchaseReturnItems);
        final product = row.readTable(db.products);
        return {
          'name': product.nameAr,
          'price': item.unitPrice,
          'quantity': item.quantity,
          'total': item.total,
        };
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesReturnsAsync = ref.watch(salesReturnsProvider);
    final purchaseReturnsAsync = ref.watch(purchaseReturnsProvider);

    final double totalSalesReturns = salesReturnsAsync.asData?.value.fold<double>(0.0, (sum, r) => sum + r.total) ?? 0.0;
    final double totalPurchaseReturns = purchaseReturnsAsync.asData?.value.fold<double>(0.0, (sum, r) => sum + r.total) ?? 0.0;
    final int totalCount = (salesReturnsAsync.asData?.value.length ?? 0) + (purchaseReturnsAsync.asData?.value.length ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة المرتجعات',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'متابعة وإدارة مرتجعات المبيعات والمشتريات والتقارير المتعلقة بها',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_tabController.index == 0) {
                      showDialog(context: context, builder: (c) => const NewSalesReturnDialog());
                    } else {
                      showDialog(context: context, builder: (c) => const NewPurchaseReturnDialog());
                    }
                  },
                  icon: const Icon(LucideIcons.plus, size: 20),
                  label: Text(
                    'إضافة مرتجع جديد',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Statistics Summary Cards
            Row(
              children: [
                _buildStatCard(
                  title: 'إجمالي مرتجعات المبيعات',
                  value: '${totalSalesReturns.toStringAsFixed(2)} ج.م',
                  icon: LucideIcons.arrowUpLeft,
                  color: AppColors.error,
                ),
                SizedBox(width: 16.w),
                _buildStatCard(
                  title: 'إجمالي مرتجعات المشتريات',
                  value: '${totalPurchaseReturns.toStringAsFixed(2)} ج.م',
                  icon: LucideIcons.arrowDownRight,
                  color: AppColors.success,
                ),
                SizedBox(width: 16.w),
                _buildStatCard(
                  title: 'إجمالي عدد المرتجعات',
                  value: '$totalCount عملية',
                  icon: LucideIcons.rotateCcw,
                  color: AppColors.primary,
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Search and Date Filter
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث برقم المرتجع أو رقم الفاتورة...',
                        hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14.sp, color: AppColors.textSecondary),
                        prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSecondary, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
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
                  label: Text(
                    _selectedDate == null ? 'تصفية بالتاريخ' : intl.DateFormat('yyyy/MM/dd').format(_selectedDate!),
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                if (_selectedDate != null) ...[
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: const Icon(LucideIcons.xCircle, color: AppColors.error),
                    onPressed: () => setState(() => _selectedDate = null),
                    tooltip: 'إلغاء التصفية',
                  ),
                ],
              ],
            ),
            SizedBox(height: 16.h),

            // Tabs Header
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15.sp),
                unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 15.sp),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'مرتجعات المبيعات', icon: Icon(LucideIcons.shoppingBag, size: 20)),
                  Tab(text: 'مرتجعات المشتريات', icon: Icon(LucideIcons.shoppingCart, size: 20)),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Tab Views Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSalesReturnsTab(),
                  _buildPurchaseReturnsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp, fontFamily: 'Cairo')),
                SizedBox(height: 4.h),
                Text(value, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesReturnsTab() {
    final returnsAsync = ref.watch(salesReturnsProvider);

    return returnsAsync.when(
      data: (returns) {
        var filtered = returns.where((r) {
          final queryMatch = r.returnNumber.contains(_searchQuery) || (r.invoiceId?.toString().contains(_searchQuery) ?? false);
          final dateMatch = _selectedDate == null ||
              (r.createdAt.year == _selectedDate!.year &&
                  r.createdAt.month == _selectedDate!.month &&
                  r.createdAt.day == _selectedDate!.day);
          return queryMatch && dateMatch;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.rotateCcw, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                SizedBox(height: 12.h),
                Text('لا توجد مرتجعات مبيعات مطابقة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 16.sp)),
              ],
            ),
          );
        }

        return _buildTableContainer(
          headers: const ['رقم المرتجع', 'رقم الفاتورة الأصلية', 'المبلغ المسترد', 'طريقة الاسترداد', 'التاريخ والوقت', 'الإجراءات'],
          rows: filtered.map((r) {
            return DataRow(cells: [
              DataCell(Text('#${r.returnNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
              DataCell(Text(r.invoiceId != null ? '#${r.invoiceId}' : 'مرتجع مباشر', style: TextStyle(fontFamily: 'Cairo', color: r.invoiceId != null ? AppColors.primary : AppColors.textSecondary))),
              DataCell(Text('${r.total.toStringAsFixed(2)} ج.م', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
              DataCell(
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: r.paymentMethod == 'cash' ? AppColors.successLight : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    r.paymentMethod == 'cash' ? 'نقدي (كاش)' : 'آجل (خصم دَين)',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: r.paymentMethod == 'cash' ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ),
              DataCell(Text(intl.DateFormat('yyyy/MM/dd  hh:mm a').format(r.createdAt), style: const TextStyle(fontFamily: 'Cairo'))),
              DataCell(
                OutlinedButton.icon(
                  onPressed: () => _showReturnDetails(context, returnNumber: r.returnNumber, title: 'تفاصيل مرتجع مبيعات', returnId: r.id, isSales: true),
                  icon: const Icon(LucideIcons.eye, size: 16),
                  label: Text('عرض الاصناف', style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  ),
                ),
              ),
            ]);
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
    );
  }

  Widget _buildPurchaseReturnsTab() {
    final returnsAsync = ref.watch(purchaseReturnsProvider);

    return returnsAsync.when(
      data: (returns) {
        var filtered = returns.where((r) {
          final queryMatch = r.returnNumber.contains(_searchQuery) || (r.invoiceId?.toString().contains(_searchQuery) ?? false);
          final dateMatch = _selectedDate == null ||
              (r.createdAt.year == _selectedDate!.year &&
                  r.createdAt.month == _selectedDate!.month &&
                  r.createdAt.day == _selectedDate!.day);
          return queryMatch && dateMatch;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.rotateCw, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                SizedBox(height: 12.h),
                Text('لا توجد مرتجعات مشتريات مطابقة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 16.sp)),
              ],
            ),
          );
        }

        return _buildTableContainer(
          headers: const ['رقم المرتجع', 'رقم الفاتورة الأصلية', 'المبلغ المسترد', 'طريقة الاسترداد', 'التاريخ والوقت', 'الإجراءات'],
          rows: filtered.map((r) {
            return DataRow(cells: [
              DataCell(Text('#${r.returnNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
              DataCell(Text(r.invoiceId != null ? '#${r.invoiceId}' : 'مرتجع مباشر', style: TextStyle(fontFamily: 'Cairo', color: r.invoiceId != null ? AppColors.primary : AppColors.textSecondary))),
              DataCell(Text('${r.total.toStringAsFixed(2)} ج.م', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
              DataCell(
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: r.paymentMethod == 'cash' ? AppColors.successLight : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    r.paymentMethod == 'cash' ? 'نقدي (كاش)' : 'آجل (خصم دَين)',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: r.paymentMethod == 'cash' ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ),
              DataCell(Text(intl.DateFormat('yyyy/MM/dd  hh:mm a').format(r.createdAt), style: const TextStyle(fontFamily: 'Cairo'))),
              DataCell(
                OutlinedButton.icon(
                  onPressed: () => _showReturnDetails(context, returnNumber: r.returnNumber, title: 'تفاصيل مرتجع مشتريات', returnId: r.id, isSales: false),
                  icon: const Icon(LucideIcons.eye, size: 16),
                  label: Text('عرض الاصناف', style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  ),
                ),
              ),
            ]);
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
    );
  }

  Widget _buildTableContainer({required List<String> headers, required List<DataRow> rows}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.background),
                  headingTextStyle: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                  ),
                  dataTextStyle: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                  ),
                  columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
                  rows: rows,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
