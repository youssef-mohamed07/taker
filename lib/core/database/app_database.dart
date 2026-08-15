import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/all_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Permissions,
    Categories,
    Brands,
    Units,
    Products,
    ProductBarcodes,
    ProductPriceHistory,
    Customers,
    Suppliers,
    Invoices,
    InvoiceItems,
    SuspendedInvoices,
    PurchaseInvoices,
    PurchaseItems,
    StockMovements,
    InventoryCounts,
    InventoryCountItems,
    Treasury,
    TreasuryTransactions,
    ExpenseCategories,
    Shifts,
    Partners,
    PartnerWithdrawals,
    PartnerProfits,
    AuditLog,
    AppSettings,
    SalesReturns,
    SalesReturnItems,
    PurchaseReturns,
    PurchaseReturnItems,
    ProductBatches,
    Workers,
    SalaryPayments,
    FawryMachine,
    FawryTransactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for tests: pass an in-memory executor.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 8;

  static String _sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Insert default data
        await _insertDefaults();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          try {
            await m.addColumn(treasuryTransactions, treasuryTransactions.shiftId);
          } catch (_) {}
          try {
            await m.addColumn(invoices, invoices.shiftId);
          } catch (_) {}
          try {
            await m.addColumn(purchaseInvoices, purchaseInvoices.shiftId);
          } catch (_) {}
          try {
            await m.createTable(shifts);
          } catch (_) {}
        }
        if (from < 3) {
          try {
            await m.addColumn(shifts, shifts.companionNames);
          } catch (_) {}
        }
        if (from < 4) {
          try {
            await m.createTable(salesReturns);
            await m.createTable(salesReturnItems);
            await m.createTable(purchaseReturns);
            await m.createTable(purchaseReturnItems);
          } catch (_) {}
        }
        if (from < 5) {
          try {
            await m.createTable(productBatches);
          } catch (_) {}

        }
        if (from < 6) {
          // Hash legacy plaintext passwords (e.g. the seeded admin123 row).
          final hex64 = RegExp(r'^[0-9a-f]{64}$');
          final allUsers = await select(users).get();
          for (final u in allUsers) {
            if (!hex64.hasMatch(u.passwordHash)) {
              await (update(users)..where((t) => t.id.equals(u.id))).write(
                UsersCompanion(passwordHash: Value(_sha256Hex(u.passwordHash))),
              );
            }
          }
        }
        if (from < 7) {
          try {
            await m.createTable(workers);
          } catch (_) {}
          try {
            await m.createTable(salaryPayments);
          } catch (_) {}
          try {
            await m.addColumn(treasuryTransactions, treasuryTransactions.paymentMethod);
          } catch (_) {}
          // Legacy rows predate payment channels: treat as cash.
          await customStatement(
            "UPDATE treasury_transactions SET payment_method = 'cash' WHERE payment_method IS NULL;",
          );
        }
        if (from < 8) {
          try {
            await m.createTable(fawryMachine);
            await m.createTable(fawryTransactions);
          } catch (_) {}
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        try {
          await customStatement('ALTER TABLE treasury_transactions ADD COLUMN shift_id INTEGER;');
        } catch (_) {}
        try {
          await customStatement('ALTER TABLE invoices ADD COLUMN shift_id INTEGER;');
        } catch (_) {}
        try {
          await customStatement('ALTER TABLE purchase_invoices ADD COLUMN shift_id INTEGER;');
        } catch (_) {}
      },
    );
  }

  Future<void> _insertDefaults() async {
    // Default admin user (password: admin123, stored as sha256 hex)
    await into(users).insert(
      UsersCompanion.insert(
        username: 'admin',
        passwordHash: _sha256Hex('admin123'),
        fullName: 'مدير النظام',
        role: 'admin',
      ),
    );

    // Default units
    final defaultUnits = [
      'قطعة',
      'كرتونة',
      'علبة',
      'كيلو',
      'لتر',
      'متر',
      'درزن',
    ];
    for (final unit in defaultUnits) {
      await into(units).insert(UnitsCompanion.insert(name: unit));
    }

    // Default treasury
    await into(
      treasury,
    ).insert(TreasuryCompanion.insert(name: 'الخزنة الرئيسية'));

    // Default expense categories
    final defaultExpenses = [
      'إيجار',
      'كهرباء',
      'مياه',
      'رواتب',
      'صيانة',
      'نقل',
      'أخرى',
    ];
    for (final exp in defaultExpenses) {
      await into(
        expenseCategories,
      ).insert(ExpenseCategoriesCompanion.insert(name: exp));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFolder = Directory(p.join(dir.path, 'Tager'));
    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }
    final file = File(p.join(dbFolder.path, 'tager_db.sqlite'));
    // Seed the runtime database from the bundled asset on first launch
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/tager_db.sqlite');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return NativeDatabase.createInBackground(file);
  });
}
