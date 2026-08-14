import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Global provider container, assigned in main() so non-widget code
/// (e.g. the router guard) can read session state.
late ProviderContainer appContainer;

/// Global database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Theme mode provider
final themeModeProvider = StateProvider<bool>((ref) => false); // false = light

/// Current user ID provider (set after login)
final currentUserIdProvider = StateProvider<int?>((ref) => null);

/// Currently logged-in user object
final currentUserProvider = StateProvider<User?>((ref) => null);

/// Permissions of the current user
final permissionsProvider = StreamProvider<List<Permission>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final db = ref.watch(databaseProvider);
  if (uid == null) return Stream.value([]);
  return (db.select(db.permissions)..where((t) => t.userId.equals(uid))).watch();
});

/// Sidebar collapsed state
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Stream Providers for Real-time Database Persistence across UI

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.customers).watch();
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.suppliers).watch();
});

final partnersStreamProvider = StreamProvider<List<Partner>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.partners).watch();
});

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.products).watch();
});

final productBarcodesStreamProvider =
    StreamProvider<List<ProductBarcode>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.productBarcodes).watch();
});

final productBatchesStreamProvider =
    StreamProvider<List<ProductBatche>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.productBatches).watch();
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

final brandsStreamProvider = StreamProvider<List<Brand>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.brands).watch();
});

final unitsStreamProvider = StreamProvider<List<Unit>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.units).watch();
});

final treasuryStreamProvider = StreamProvider<List<TreasuryData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.treasury).watch();
});

final expenseCategoriesStreamProvider =
    StreamProvider<List<ExpenseCategory>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.expenseCategories).watch();
});

final treasuryTransactionsStreamProvider =
    StreamProvider<List<TreasuryTransaction>>((ref) {
      final db = ref.watch(databaseProvider);
      return (db.select(
        db.treasuryTransactions,
      )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
    });

final stockMovementsStreamProvider = StreamProvider<List<StockMovement>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.stockMovements,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
});

final purchaseInvoicesStreamProvider = StreamProvider<List<PurchaseInvoice>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.purchaseInvoices,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
});

final salesInvoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.invoices,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
});

final invoiceItemsStreamProvider = StreamProvider<List<InvoiceItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.invoiceItems).watch();
});

final purchaseItemsStreamProvider =
    StreamProvider<List<PurchaseItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.purchaseItems).watch();
});

final shiftsStreamProvider = StreamProvider<List<Shift>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.shifts,
  )..orderBy([(t) => OrderingTerm.desc(t.openedAt)])).watch();
});

final auditLogsStreamProvider = StreamProvider<List<AuditLogData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.auditLog,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
});

final usersStreamProvider = StreamProvider<List<User>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.users).watch();
});

final workersStreamProvider = StreamProvider<List<Worker>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.workers).watch();
});

final salaryPaymentsStreamProvider =
    StreamProvider<List<SalaryPayment>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.salaryPayments)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();
});
