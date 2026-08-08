import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/database/db_helpers.dart';
import '../../../../core/database/app_database.dart';

class SuppliersView extends ConsumerStatefulWidget {
  const SuppliersView({super.key});

  @override
  ConsumerState<SuppliersView> createState() => _SuppliersViewState();
}

class _SuppliersViewState extends ConsumerState<SuppliersView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddSupplierDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddSupplierDialog(),
    );
  }


  void _showPayDebtDialog(Supplier supplier) {
    if (supplier.balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المورد ليس له مستحقات.'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: supplier.balance.toStringAsFixed(2));
    final notesController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('سداد دفعة للمورد: ${supplier.name}', style: const TextStyle(fontFamily: 'Cairo')),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'إجمالي المستحق: ${supplier.balance.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.warning),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المسدد (ج.م)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'مطلوب';
                        final num = double.tryParse(val);
                        if (num == null || num <= 0) return 'قيمة غير صالحة';
                        if (num > supplier.balance) return 'المبلغ يتجاوز المستحق';
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
                            await DbHelpers.paySupplierDebt(
                              db,
                              supplierId: supplier.id,
                              amount: amount,
                              userId: 1, // Currently hardcoded user 1
                              notes: notesController.text.isNotEmpty ? notesController.text : null,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم السداد بنجاح وخصم المبلغ من الخزنة.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              ref.invalidate(suppliersStreamProvider);
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
                      : const Text('تأكيد السداد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSupplierDetailsDialog(Supplier supplier) {
    showDialog(
      context: context,
      builder: (context) => SupplierDetailsDialog(supplier: supplier),
    );
  }

  void _showEditSupplierDialog(Supplier supplier) {
    showDialog(
      context: context,
      builder: (context) => EditSupplierDialog(supplier: supplier),
    );
  }

  Future<void> _confirmDeleteSupplier(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text(
              'تأكيد الحذف',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف المورد "${supplier.name}"؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف المورد', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final db = ref.read(databaseProvider);
        await DbHelpers.deleteSupplier(db, supplier.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'تم حذف المورد بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'فشل حذف المورد: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);

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
                        'الموردين',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'إدارة شركات الموردين والمستحقات الفواتير',
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
                  onPressed: _showAddSupplierDialog,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text(
                    'مورد جديد',
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
                  hintText: 'البحث باسم المورد أو رقم الهاتف...',
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
            // Main List Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: suppliersAsync.when(
                  data: (suppliers) {
                    final filtered = suppliers.where((s) {
                      if (_searchQuery.isEmpty) return true;
                      return s.name.contains(_searchQuery) ||
                          (s.phone != null && s.phone!.contains(_searchQuery));
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.truck,
                              size: 48,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              suppliers.isEmpty
                                  ? 'لا يوجد موردين مضافين حالياً'
                                  : 'لم يتم العثور على نتائج مطابقة',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            if (suppliers.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddSupplierDialog,
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text(
                                  'إضافة أول مورد',
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
                        final supplier = filtered[index];
                        final hasDebt = supplier.balance > 0;

                        return InkWell(
                          onTap: () => _showSupplierDetailsDialog(supplier),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: hasDebt
                                      ? Colors.amber.shade50
                                      : AppColors.primarySurface,
                                  child: Text(
                                    supplier.name.substring(0, 1),
                                    style: TextStyle(
                                      color: hasDebt
                                          ? Colors.amber.shade900
                                          : AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supplier.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            LucideIcons.phone,
                                            size: 13,
                                            color: AppColors.textTertiary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            supplier.phone ?? 'بدون رقم هاتف',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                          if (supplier.address != null &&
                                              supplier.address!.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            Icon(
                                              LucideIcons.mapPin,
                                              size: 13,
                                              color: AppColors.textTertiary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              supplier.address!,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${supplier.balance.toStringAsFixed(2)} ج.م',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: hasDebt
                                            ? AppColors.warning
                                            : AppColors.success,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    Text(
                                      hasDebt ? 'مستحق للمورد' : 'رصيد متعادل',
                                      style: TextStyle(
                                        color: hasDebt
                                            ? AppColors.warning
                                            : AppColors.textTertiary,
                                        fontSize: 11,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Action buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (supplier.balance > 0)
                                      IconButton(
                                        icon: const Icon(LucideIcons.wallet, size: 18),
                                        tooltip: 'سداد دفعة',
                                        color: AppColors.warning,
                                        onPressed: () =>
                                            _showPayDebtDialog(supplier),
                                      ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.eye,
                                          size: 18),
                                      color: AppColors.primary,
                                      tooltip: 'عرض التفاصيل',
                                      onPressed: () =>
                                          _showSupplierDetailsDialog(supplier),
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.edit2,
                                          size: 18),
                                      color: AppColors.textSecondary,
                                      tooltip: 'تعديل البيانات',
                                      onPressed: () =>
                                          _showEditSupplierDialog(supplier),
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.trash2,
                                          size: 18),
                                      color: AppColors.error,
                                      tooltip: 'حذف المورد',
                                      onPressed: () =>
                                          _confirmDeleteSupplier(supplier),
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

/// Dialog to view supplier details
class SupplierDetailsDialog extends ConsumerWidget {
  final Supplier supplier;
  const SupplierDetailsDialog({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDebt = supplier.balance > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      hasDebt ? Colors.amber.shade50 : AppColors.primarySurface,
                  child: Text(
                    supplier.name.substring(0, 1),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: hasDebt
                          ? Colors.amber.shade900
                          : AppColors.primary,
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
                        supplier.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'كود المورد: #${supplier.id.toString().padLeft(4, '0')}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
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
            const Divider(height: 28),

            // Balance summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasDebt
                    ? AppColors.warning.withValues(alpha: 0.08)
                    : AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasDebt
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasDebt
                        ? LucideIcons.arrowUpRight
                        : LucideIcons.checkCircle2,
                    color: hasDebt ? AppColors.warning : AppColors.success,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مستحقات المورد الحالية',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${supplier.balance.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color:
                                hasDebt ? AppColors.warning : AppColors.success,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasDebt ? AppColors.warning : AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasDebt ? 'مستحق للمورد' : 'خالص المسحوبات',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Information grid
            _buildDetailRow(
              icon: LucideIcons.phone,
              label: 'رقم الهاتف',
              value: supplier.phone ?? 'غير مسجل',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: LucideIcons.mapPin,
              label: 'العنوان',
              value: supplier.address ?? 'غير مسجل',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: LucideIcons.calendar,
              label: 'تاريخ الإضافة',
              value:
                  '${supplier.createdAt.year}/${supplier.createdAt.month.toString().padLeft(2, '0')}/${supplier.createdAt.day.toString().padLeft(2, '0')}',
            ),
            if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: LucideIcons.fileText,
                label: 'الملاحظات',
                value: supplier.notes!,
              ),
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showDialog(
                      context: context,
                      builder: (context) => EditSupplierDialog(supplier: supplier),
                    );
                  },
                  icon: const Icon(LucideIcons.edit2, size: 16),
                  label: const Text('تعديل البيانات',
                      style: TextStyle(fontFamily: 'Cairo')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق',
                      style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog to edit supplier
class EditSupplierDialog extends ConsumerStatefulWidget {
  final Supplier supplier;
  const EditSupplierDialog({super.key, required this.supplier});

  @override
  ConsumerState<EditSupplierDialog> createState() => _EditSupplierDialogState();
}

class _EditSupplierDialogState extends ConsumerState<EditSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _balanceController;
  late final TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier.name);
    _phoneController = TextEditingController(text: widget.supplier.phone ?? '');
    _addressController =
        TextEditingController(text: widget.supplier.address ?? '');
    _balanceController =
        TextEditingController(text: widget.supplier.balance.toString());
    _notesController = TextEditingController(text: widget.supplier.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      await DbHelpers.updateSupplier(
        db,
        id: widget.supplier.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        balance: double.tryParse(_balanceController.text.trim()) ?? 0.0,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تحديث بيانات المورد بنجاح',
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
              'حدث خطأ أثناء التحديث: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
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
                    'تعديل بيانات المورد',
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
                  labelText: 'اسم المورد *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'الرجاء إدخال اسم المورد'
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
                        labelText: 'الرصيد المستحق له (ج.م)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
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
                    child: const Text('إلغاء',
                        style: TextStyle(fontFamily: 'Cairo')),
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
                        : const Text('حفظ التغييرات',
                            style: TextStyle(fontFamily: 'Cairo')),
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

/// Dialog to add a new supplier
class AddSupplierDialog extends ConsumerStatefulWidget {
  const AddSupplierDialog({super.key});

  @override
  ConsumerState<AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends ConsumerState<AddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      await DbHelpers.addSupplier(
        db,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        balance: double.tryParse(_balanceController.text.trim()) ?? 0.0,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تمت إضافة المورد بنجاح',
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
                    'إضافة مورد جديد',
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
                  labelText: 'اسم المورد *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'الرجاء إدخال اسم المورد'
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
                        labelText: 'الرصيد الأولي (مستحق له)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
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
                            'حفظ المورد',
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
