import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/database/app_database.dart';

class CustomersView extends ConsumerStatefulWidget {
  const CustomersView({super.key});

  @override
  ConsumerState<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends ConsumerState<CustomersView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );
  }

  void _showEditCustomerDialog(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => EditCustomerDialog(customer: customer),
    );
  }


  void _showReceivePaymentDialog(Customer customer) {
    if (customer.balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('العميل ليس عليه مديونية.'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: customer.balance.toStringAsFixed(2));
    final notesController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('تحصيل دفعة من ${customer.name}', style: const TextStyle(fontFamily: 'Cairo')),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'إجمالي المديونية: ${customer.balance.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المحصل (ج.م)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'مطلوب';
                        final num = double.tryParse(val);
                        if (num == null || num <= 0) return 'قيمة غير صالحة';
                        if (num > customer.balance) return 'المبلغ يتجاوز المديونية';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
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
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);
                          try {
                            final db = ref.read(databaseProvider);
                            final amount = double.parse(amountController.text);
                            await DbHelpers.receiveCustomerPayment(
                              db,
                              customerId: customer.id,
                              amount: amount,
                              userId: 1, // Currently hardcoded user 1
                              notes: notesController.text.isNotEmpty ? notesController.text : null,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم التحصيل بنجاح وتحديث الخزنة.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              // Refresh
                              ref.invalidate(customersStreamProvider);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e')),
                              );
                            }
                          } finally {
                            setDialogState(() => isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تأكيد التحصيل', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomerDetailsDialog(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => CustomerDetailsDialog(
        customer: customer,
        onEdit: () {
          Navigator.of(context).pop();
          _showEditCustomerDialog(customer);
        },
        onDelete: () {
          Navigator.of(context).pop();
          _confirmDeleteCustomer(customer);
        },
      ),
    );
  }

  void _confirmDeleteCustomer(Customer customer) {
    if (customer.balance != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف عميل لديه رصيد أو مديونية. يرجى تسوية الحساب أولاً.', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.error),
            SizedBox(width: 8),
            Text(
              'تأكيد حذف العميل',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'هل أنت تأكد من رغبتك في حذف العميل "${customer.name}"؟\nسيتم حذف بياناته نهائياً من قاعدة البيانات.',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final db = ref.read(databaseProvider);
              await DbHelpers.deleteCustomer(db, customer.id);
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم حذف العميل بنجاح',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              );
            },
            child: const Text(
              'حذف',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العملاء',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'إدارة بيانات العملاء وكشوف الحسابات',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddCustomerDialog,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text(
                    'عميل جديد',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Search Bar
            SizedBox(
              width: 350,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'البحث باسم العميل أو رقم الهاتف...',
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: customersAsync.when(
                  data: (customers) {
                    final filtered = customers.where((c) {
                      if (_searchQuery.isEmpty) return true;
                      return c.name.contains(_searchQuery) ||
                          (c.phone != null && c.phone!.contains(_searchQuery));
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.users,
                              size: 48,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              customers.isEmpty
                                  ? 'لا يوجد عملاء مضافين حالياً'
                                  : 'لم يتم العثور على نتائج مطابقة',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            if (customers.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddCustomerDialog,
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text(
                                  'إضافة أول عميل',
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = filtered[index];
                        return InkWell(
                          onTap: () => _showCustomerDetailsDialog(customer),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primarySurface,
                                  child: Text(
                                    customer.name.isNotEmpty
                                        ? customer.name.substring(0, 1)
                                        : '؟',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        customer.phone ?? 'بدون رقم هاتف',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${customer.balance.toStringAsFixed(2)} ج.م',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: customer.balance > 0
                                            ? AppColors.error
                                            : AppColors.success,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    Text(
                                      customer.balance > 0
                                          ? 'مديونية'
                                          : 'رصيد متعادل',
                                      style: const TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (customer.balance > 0)
                                      IconButton(
                                        icon: const Icon(LucideIcons.wallet, size: 18),
                                        tooltip: 'تحصيل مديونية',
                                        color: AppColors.success,
                                        onPressed: () =>
                                            _showReceivePaymentDialog(customer),
                                      ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.eye, size: 18),
                                      tooltip: 'عرض التفاصيل',
                                      color: AppColors.primary,
                                      onPressed: () =>
                                          _showCustomerDetailsDialog(customer),
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.edit, size: 18),
                                      tooltip: 'تعديل العميل',
                                      color: AppColors.textSecondary,
                                      onPressed: () =>
                                          _showEditCustomerDialog(customer),
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.trash2, size: 18),
                                      tooltip: 'حذف العميل',
                                      color: AppColors.error,
                                      onPressed: () =>
                                          _confirmDeleteCustomer(customer),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(
                      'خطأ: $err',
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerDetailsDialog extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CustomerDetailsDialog({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final balanceColor = customer.balance > 0
        ? AppColors.error
        : (customer.balance < 0 ? AppColors.warning : AppColors.success);
    final balanceText = customer.balance > 0
        ? 'مديونية (مستحق عليه)'
        : (customer.balance < 0 ? 'رصيد دائن (له)' : 'رصيد متعادل');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primarySurface,
                  child: Text(
                    customer.name.isNotEmpty ? customer.name.substring(0, 1) : '؟',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        customer.phone ?? 'بدون رقم هاتف',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: balanceColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: balanceColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    customer.balance > 0
                        ? LucideIcons.alertCircle
                        : LucideIcons.checkCircle,
                    color: balanceColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: balanceColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${customer.balance.abs().toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: balanceColor,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'الحد الائتماني',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${customer.creditLimit.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(LucideIcons.mapPin, 'العنوان', customer.address ?? 'غير محدد'),
            const SizedBox(height: 10),
            _buildDetailRow(LucideIcons.phone, 'رقم الهاتف', customer.phone ?? 'غير محدد'),
            const SizedBox(height: 10),
            _buildDetailRow(LucideIcons.fileText, 'ملاحظات', customer.notes ?? 'لا يوجد ملاحظات'),
            const SizedBox(height: 10),
            _buildDetailRow(
              LucideIcons.calendar,
              'تاريخ الإضافة',
              customer.createdAt.toString().split('.')[0],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                  label: const Text(
                    'حذف',
                    style: TextStyle(fontFamily: 'Cairo', color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(LucideIcons.edit, size: 16),
                  label: const Text(
                    'تعديل البيانات',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }
}

class AddCustomerDialog extends ConsumerStatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  ConsumerState<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends ConsumerState<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  final _creditLimitController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      await DbHelpers.addCustomer(
        db,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        balance: double.tryParse(_balanceController.text.trim()) ?? 0.0,
        creditLimit: double.tryParse(_creditLimitController.text.trim()) ?? 0.0,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تمت إضافة العميل بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'إضافة عميل جديد',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'الرجاء إدخال اسم العميل'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _balanceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الرصيد الأولي (مديونية)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _creditLimitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الحد الائتماني',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'حفظ العميل',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditCustomerDialog extends ConsumerStatefulWidget {
  final Customer customer;
  const EditCustomerDialog({super.key, required this.customer});

  @override
  ConsumerState<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends ConsumerState<EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _balanceController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone ?? '');
    _addressController = TextEditingController(text: widget.customer.address ?? '');
    _balanceController = TextEditingController(text: widget.customer.balance.toString());
    _creditLimitController = TextEditingController(text: widget.customer.creditLimit.toString());
    _notesController = TextEditingController(text: widget.customer.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      await DbHelpers.updateCustomer(
        db,
        id: widget.customer.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        balance: double.tryParse(_balanceController.text.trim()) ?? 0.0,
        creditLimit: double.tryParse(_creditLimitController.text.trim()) ?? 0.0,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تحديث بيانات العميل بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'تعديل بيانات العميل',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'الرجاء إدخال اسم العميل'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _balanceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الرصيد / المديونية',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _creditLimitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الحد الائتماني',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'تحديث البيانات',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
