import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tager/core/auth/auth_service.dart';
import 'package:tager/core/database/app_database.dart';
import 'package:tager/core/database/db_helpers.dart';

AppDatabase _newDb() => AppDatabase.withExecutor(NativeDatabase.memory());

void main() {
  group('DbHelpers.getShiftSummary', () {
    test('folds income/expense treasury types into expected balance', () async {
      final db = _newDb();
      final shiftId =
          await DbHelpers.openShift(db, openingBalance: 100, userId: 1);
      final shift = await (db.select(db.shifts)
            ..where((t) => t.id.equals(shiftId)))
          .getSingle();

      Future<void> tx(String type, double amount) =>
          db.into(db.treasuryTransactions).insert(
                TreasuryTransactionsCompanion.insert(
                  treasuryId: 1,
                  shiftId: Value(shiftId),
                  type: type,
                  amount: amount,
                  userId: 1,
                ),
              );

      await tx('INCOME', 50);
      await tx('DEPOSIT', 25);
      await tx('EXPENSE', 20);
      await tx('WITHDRAWAL', 10);

      final summary = await DbHelpers.getShiftSummary(db, shift);
      expect(summary['opening'], 100);
      expect(summary['income'], 75);
      expect(summary['expense'], 30);
      expect(summary['net'], 45);
      expect(summary['expected'], 145);

      await db.close();
    });
  });

  group('saveSalesInvoice FIFO batch deduction', () {
    test('deducts from the oldest-expiring batch first', () async {
      final db = _newDb();
      await DbHelpers.addProduct(
        db,
        nameAr: 'منتج اختبار',
        purchasePrice: 10,
        retailPrice: 20,
        wholesalePrice: 18,
        initialQuantity: 10,
        minQuantity: 1,
        userId: 1,
      );
      final product =
          await (db.select(db.products)..where((t) => t.nameAr.equals('منتج اختبار')))
              .getSingle();

      final now = DateTime.now();
      // Newer expiry inserted first on purpose: ordering must use expiryDate.
      await db.into(db.productBatches).insert(
            ProductBatchesCompanion.insert(
              productId: product.id,
              quantity: const Value(5.0),
              expiryDate: Value(now.add(const Duration(days: 30))),
            ),
          );
      await db.into(db.productBatches).insert(
            ProductBatchesCompanion.insert(
              productId: product.id,
              quantity: const Value(5.0),
              expiryDate: Value(now.add(const Duration(days: 10))),
            ),
          );

      await DbHelpers.saveSalesInvoice(
        db,
        items: [
          PosCartItem(product: product, quantity: 7, unitPrice: 20),
        ],
        subtotal: 140,
        discount: 0,
        total: 140,
        paid: 140,
        paymentMethod: 'cash',
        userId: 1,
      );

      final batches = await (db.select(db.productBatches)
            ..where((t) => t.productId.equals(product.id))
            ..orderBy([(t) => OrderingTerm.asc(t.expiryDate)]))
          .get();
      // Oldest (10-day) batch fully consumed, newer one partially.
      expect(batches[0].quantity, 0);
      expect(batches[1].quantity, 3);

      final fresh = await (db.select(db.products)
            ..where((t) => t.id.equals(product.id)))
          .getSingle();
      expect(fresh.currentQuantity, 3);

      await db.close();
    });
  });

  group('DbHelpers.voidSalesInvoice', () {
    test('reverses stock, treasury and marks invoice voided', () async {
      final db = _newDb();
      await DbHelpers.addProduct(
        db,
        nameAr: 'منتج الإلغاء',
        purchasePrice: 10,
        retailPrice: 20,
        wholesalePrice: 18,
        initialQuantity: 10,
        minQuantity: 1,
        userId: 1,
      );
      final product = await (db.select(db.products)
            ..where((t) => t.nameAr.equals('منتج الإلغاء')))
          .getSingle();

      final treasuryBefore =
          await (db.select(db.treasury)..where((t) => t.id.equals(1)))
              .getSingle();

      final invoiceId = await DbHelpers.saveSalesInvoice(
        db,
        items: [PosCartItem(product: product, quantity: 4, unitPrice: 20)],
        subtotal: 80,
        discount: 0,
        total: 80,
        paid: 80,
        paymentMethod: 'cash',
        userId: 1,
      );

      await DbHelpers.voidSalesInvoice(db, invoiceId);

      final invoice = await (db.select(db.invoices)
            ..where((t) => t.id.equals(invoiceId)))
          .getSingle();
      expect(invoice.status, 'voided');

      final fresh = await (db.select(db.products)
            ..where((t) => t.id.equals(product.id)))
          .getSingle();
      expect(fresh.currentQuantity, 10); // stock fully restored

      final treasuryAfter =
          await (db.select(db.treasury)..where((t) => t.id.equals(1)))
              .getSingle();
      expect(treasuryAfter.currentBalance, treasuryBefore.currentBalance);

      final reversal = await (db.select(db.treasuryTransactions)
            ..where((t) => t.referenceType.equals('void_sales_invoice')))
          .get();
      expect(reversal.length, 1);
      expect(reversal.first.type, 'EXPENSE');
      expect(reversal.first.amount, 80);

      // Voiding twice must be a no-op.
      await DbHelpers.voidSalesInvoice(db, invoiceId);
      final freshAgain = await (db.select(db.products)
            ..where((t) => t.id.equals(product.id)))
          .getSingle();
      expect(freshAgain.currentQuantity, 10);

      await db.close();
    });
  });

  group('Multi-wallet money model', () {
    test('card sale accrues to card wallet, drawer untouched; transfer moves it', () async {
      final db = _newDb();
      await DbHelpers.addProduct(
        db,
        nameAr: 'منتج المحفظة',
        purchasePrice: 10,
        retailPrice: 20,
        wholesalePrice: 18,
        initialQuantity: 10,
        minQuantity: 1,
        userId: 1,
      );
      final product = await (db.select(db.products)
            ..where((t) => t.nameAr.equals('منتج المحفظة')))
          .getSingle();

      final drawerBefore =
          (await (db.select(db.treasury)..where((t) => t.id.equals(1))).getSingle())
              .currentBalance;

      await DbHelpers.saveSalesInvoice(
        db,
        items: [PosCartItem(product: product, quantity: 2, unitPrice: 20)],
        subtotal: 40,
        discount: 0,
        total: 40,
        paid: 40,
        paymentMethod: 'card',
        userId: 1,
      );

      final wallets = await DbHelpers.getWalletBalances(db);
      expect(wallets['cash'], drawerBefore); // drawer unaffected by card sale
      expect(wallets['card'], 40);

      await DbHelpers.transferWalletToDrawer(db, fromMethod: 'card', amount: 40, userId: 1);
      final after = await DbHelpers.getWalletBalances(db);
      expect(after['cash'], drawerBefore + 40);
      expect(after['card'], 0);

      await db.close();
    });

    test('worker salary via card deducts card wallet, drawer untouched', () async {
      final db = _newDb();
      final workerId = await DbHelpers.addWorker(
        db,
        name: 'عامل اختبار',
        dailyWage: 100,
        actorId: 1,
      );
      final drawerBefore =
          (await (db.select(db.treasury)..where((t) => t.id.equals(1))).getSingle())
              .currentBalance;

      await DbHelpers.payWorkerSalary(
        db,
        workerId: workerId,
        amount: 60,
        userId: 1,
        paymentMethod: 'card',
      );

      final wallets = await DbHelpers.getWalletBalances(db);
      expect(wallets['cash'], drawerBefore);
      expect(wallets['card'], -60);

      final payments = await db.select(db.salaryPayments).get();
      expect(payments.length, 1);
      expect(payments.first.amount, 60);

      await db.close();
    });

    test('credit sale adds debt without money move; fawry collection accrues to fawry wallet', () async {
      final db = _newDb();
      await DbHelpers.addProduct(
        db,
        nameAr: 'منتج الآجل',
        purchasePrice: 10,
        retailPrice: 20,
        wholesalePrice: 18,
        initialQuantity: 10,
        minQuantity: 1,
        userId: 1,
      );
      final product = await (db.select(db.products)
            ..where((t) => t.nameAr.equals('منتج الآجل')))
          .getSingle();
      final customerId = await DbHelpers.addCustomer(db, name: 'عميل آجل');

      await DbHelpers.saveSalesInvoice(
        db,
        items: [PosCartItem(product: product, quantity: 3, unitPrice: 20)],
        subtotal: 60,
        discount: 0,
        total: 60,
        paid: 0,
        paymentMethod: 'credit',
        customerId: customerId,
        userId: 1,
      );

      final debtor = await (db.select(db.customers)
            ..where((t) => t.id.equals(customerId)))
          .getSingle();
      expect(debtor.balance, 60);

      final wallets0 = await DbHelpers.getWalletBalances(db);
      expect(wallets0['fawry'], 0); // credit sale moves no money

      await DbHelpers.receiveCustomerPayment(
        db,
        customerId: customerId,
        amount: 25,
        userId: 1,
        paymentMethod: 'fawry',
      );

      final wallets = await DbHelpers.getWalletBalances(db);
      expect(wallets['fawry'], 25);
      final settled = await (db.select(db.customers)
            ..where((t) => t.id.equals(customerId)))
          .getSingle();
      expect(settled.balance, 35);

      await db.close();
    });
  });

  group('Password hashing', () {
    test('seeded admin stores a sha256 hash and authenticates', () async {
      final db = _newDb();
      final admin = await (db.select(db.users)
            ..where((t) => t.username.equals('admin')))
          .getSingle();

      // Not stored in plaintext.
      expect(admin.passwordHash, isNot('admin123'));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(admin.passwordHash), isTrue);

      expect(await AuthService.authenticate(db, 'admin', 'admin123'), isNotNull);
      expect(await AuthService.authenticate(db, 'admin', 'wrong'), isNull);

      await db.close();
    });
  });
}
