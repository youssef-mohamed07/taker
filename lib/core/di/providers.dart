import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Global database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Theme mode provider
final themeModeProvider = StateProvider<bool>((ref) => false); // false = light

/// Current user ID provider (set after login)
final currentUserIdProvider = StateProvider<int?>((ref) => null);

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

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

final treasuryStreamProvider = StreamProvider<List<TreasuryData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.treasury).watch();
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
