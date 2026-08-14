import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/providers.dart';

class SalesHistoryView extends ConsumerStatefulWidget {
  const SalesHistoryView({super.key});

  @override
  ConsumerState<SalesHistoryView> createState() => _SalesHistoryViewState();
}

class _SalesHistoryViewState extends ConsumerState<SalesHistoryView> {
  String _searchQuery = '';
  DateTime? _selectedDate;

  void _showInvoiceDetails(Invoice invoice, String customerName) async {
    showDialog(
      context: context,
      builder: (context) => InvoiceDetailsDialog(invoice: invoice, customerName: customerName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(salesInvoicesStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    
    // Create a customer map for quick lookup
    final Map<int, String> customerMap = {};
    customersAsync.whenData((customers) {
      for (final c in customers) {
        customerMap[c.id] = c.name;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سجل المبيعات',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
            SizedBox(height: 16.h),
            
            // Search and Filter
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث برقم الفاتورة...',
                        prefixIcon: Icon(LucideIcons.search, color: AppColors.textSecondary, size: 20),
                        border: InputBorder.none,
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
                  icon: Icon(LucideIcons.calendar, size: 18),
                  label: Text(_selectedDate == null ? 'تصفية بالتاريخ' : DateFormat('yyyy/MM/dd').format(_selectedDate!)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                  ),
                ),
                if (_selectedDate != null)
                  Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: IconButton(
                      icon: Icon(LucideIcons.xCircle, color: AppColors.error),
                      onPressed: () => setState(() => _selectedDate = null),
                    ),
                  )
              ],
            ),
            SizedBox(height: 24.h),
            
            Expanded(
              child: invoicesAsync.when(
                data: (invoices) {
                  // Filter
                  final filtered = invoices.where((inv) {
                    bool matchSearch = inv.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase());
                    bool matchDate = true;
                    if (_selectedDate != null) {
                      matchDate = inv.createdAt.year == _selectedDate!.year &&
                                  inv.createdAt.month == _selectedDate!.month &&
                                  inv.createdAt.day == _selectedDate!.day;
                    }
                    return matchSearch && matchDate;
                  }).toList();

                  // Sort by latest
                  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: filtered.isEmpty
                      ? Center(child: Text('لا توجد فواتير مطابقة', style: TextStyle(fontFamily: 'Cairo')))
                      : LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(constraints: BoxConstraints(minWidth: constraints.maxWidth), child: SingleChildScrollView(
                            child: DataTable(
                              headingTextStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              dataTextStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary),
                              columns: const [
                                DataColumn(label: Text('رقم الفاتورة')),
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('العميل')),
                                DataColumn(label: Text('الإجمالي')),
                                DataColumn(label: Text('المدفوع / المتبقي')),
                                DataColumn(label: Text('الحالة')),
                                DataColumn(label: Text('الإجراءات')),
                              ],
                              rows: filtered.map((inv) {
                                final custName = inv.customerId != null ? (customerMap[inv.customerId] ?? 'عميل محذوف') : 'عميل نقدي (طياري)';
                                
                                return DataRow(
                                  cells: [
                                    DataCell(Text(inv.invoiceNumber, style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(DateFormat('yyyy/MM/dd HH:mm').format(inv.createdAt))),
                                    DataCell(Text(custName)),
                                    DataCell(Text('${inv.total.toStringAsFixed(2)} ج.م', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text('${inv.paid.toStringAsFixed(2)} / ${inv.remaining.toStringAsFixed(2)}')),
                                    DataCell(
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: inv.status == 'voided' ? AppColors.errorLight : AppColors.successLight,
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          inv.status == 'voided' ? 'ملغاة' : 'مكتملة',
                                          style: TextStyle(
                                            color: inv.status == 'voided' ? AppColors.error : AppColors.success,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      ElevatedButton.icon(
                                        onPressed: () => _showInvoiceDetails(inv, custName),
                                        icon: Icon(LucideIcons.eye, size: 16),
                                        label: Text('التفاصيل'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primarySurface,
                                          foregroundColor: AppColors.primary,
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          )),
                        )),
                  );
                },
                loading: () => Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceDetailsDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final String customerName;

  const InvoiceDetailsDialog({super.key, required this.invoice, required this.customerName});

  @override
  ConsumerState<InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends ConsumerState<InvoiceDetailsDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final db = ref.read(databaseProvider);
    final query = db.select(db.invoiceItems).join([
      drift.innerJoin(db.products, db.products.id.equalsExp(db.invoiceItems.productId)),
    ])..where(db.invoiceItems.invoiceId.equals(widget.invoice.id));

    final results = await query.get();
    
    final items = results.map((row) {
      final item = row.readTable(db.invoiceItems);
      final product = row.readTable(db.products);
      return {
        'product': product.nameAr,
        'quantity': item.quantity,
        'price': item.unitPrice,
        'total': item.total,
      };
    }).toList();

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }
  

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 600.w,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('تفاصيل الفاتورة #${widget.invoice.invoiceNumber}', style: TextStyle(fontFamily: 'Cairo', fontSize: 18.sp, fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(LucideIcons.x), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('العميل: ${widget.customerName}', style: TextStyle(fontFamily: 'Cairo')),
                Text('التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(widget.invoice.createdAt)}', style: TextStyle(fontFamily: 'Cairo')),
              ],
            ),
            SizedBox(height: 16.h),
            _isLoading 
              ? Center(child: CircularProgressIndicator())
              : Container(
                  height: 250.h,
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        title: Text(item['product'], style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        subtitle: Text('${item['price']} ج.م × ${item['quantity']}'),
                        trailing: Text('${item['total']} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الإجمالي: ${widget.invoice.total} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp)),
                
              ],
            )
          ],
        ),
      ),
    );
  }
}
