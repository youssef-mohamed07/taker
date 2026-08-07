import 'package:drift/drift.dart';
import 'app_database.dart';

class PosCartItem {
  final Product product;
  final double quantity;
  final double unitPrice;
  final double discount;
  PosCartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
  });

  double get total => (unitPrice * quantity) - discount;
}

class PurchaseCartItem {
  final Product product;
  final double quantity;
  final double purchasePrice;
  PurchaseCartItem({
    required this.product,
    required this.quantity,
    required this.purchasePrice,
  });

  double get total => purchasePrice * quantity;
}

class DbHelpers {
  DbHelpers._();

  static Future<int> addCustomer(
    AppDatabase db, {
    required String name,
    String? phone,
    String? address,
    double balance = 0.0,
    double creditLimit = 0.0,
    String? notes,
  }) {
    return db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            name: name,
            phone: Value(phone),
            address: Value(address),
            balance: Value(balance),
            creditLimit: Value(creditLimit),
            notes: Value(notes),
          ),
        );
  }

  static Future<bool> updateCustomer(
    AppDatabase db, {
    required int id,
    required String name,
    String? phone,
    String? address,
    double balance = 0.0,
    double creditLimit = 0.0,
    String? notes,
  }) {
    return (db.update(db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        balance: Value(balance),
        creditLimit: Value(creditLimit),
        notes: Value(notes),
      ),
    ).then((rows) => rows > 0);
  }

  static Future<int> deleteCustomer(AppDatabase db, int id) {
    return (db.delete(db.customers)..where((t) => t.id.equals(id))).go();
  }

  static Future<int> addSupplier(
    AppDatabase db, {
    required String name,
    String? phone,
    String? address,
    double balance = 0.0,
    String? notes,
  }) {
    return db
        .into(db.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: name,
            phone: Value(phone),
            address: Value(address),
            balance: Value(balance),
            notes: Value(notes),
          ),
        );
  }

  static Future<bool> updateSupplier(
    AppDatabase db, {
    required int id,
    required String name,
    String? phone,
    String? address,
    double balance = 0.0,
    String? notes,
  }) {
    return (db.update(db.suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        balance: Value(balance),
        notes: Value(notes),
      ),
    ).then((rows) => rows > 0);
  }

  static Future<int> deleteSupplier(AppDatabase db, int id) {
    return (db.delete(db.suppliers)..where((t) => t.id.equals(id))).go();
  }

  static Future<int> addPartner(
    AppDatabase db, {
    required String name,
    required double sharePercentage,
    double capital = 0.0,
  }) {
    return db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(
            name: name,
            sharePercentage: sharePercentage,
            capital: Value(capital),
          ),
        );
  }

  static Future<int> addProduct(
    AppDatabase db, {
    String? internalCode,
    required String nameAr,
    String? nameEn,
    int? categoryId,
    double purchasePrice = 0,
    double retailPrice = 0,
    double wholesalePrice = 0,
    double initialQuantity = 0,
    double minQuantity = 0,
    String? barcode,
    int? userId,
  }) async {
    return db.transaction(() async {
      final productId = await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              internalCode: Value(internalCode),
              nameAr: nameAr,
              nameEn: Value(nameEn),
              categoryId: Value(categoryId),
              purchasePrice: Value(purchasePrice),
              retailPrice: Value(retailPrice),
              wholesalePrice: Value(wholesalePrice),
              currentQuantity: Value(initialQuantity),
              minQuantity: Value(minQuantity),
            ),
          );

      if (barcode != null && barcode.trim().isNotEmpty) {
        await db
            .into(db.productBarcodes)
            .insert(
              ProductBarcodesCompanion.insert(
                productId: productId,
                barcode: barcode.trim(),
                isPrimary: const Value(true),
              ),
            );
      }

      if (initialQuantity > 0 && userId != null) {
        await db
            .into(db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                productId: productId,
                movementType: 'IN',
                quantity: initialQuantity,
                referenceType: const Value('initial_stock'),
                userId: userId,
                notes: const Value('رصيد أولي'),
              ),
            );
      }

      return productId;
    });
  }

  static Future<bool> updateProduct(
    AppDatabase db, {
    required int id,
    String? internalCode,
    required String nameAr,
    String? nameEn,
    int? categoryId,
    double purchasePrice = 0,
    double retailPrice = 0,
    double wholesalePrice = 0,
    double minQuantity = 0,
    String? barcode,
  }) async {
    return db.transaction(() async {
      final rows = await (db.update(db.products)..where((t) => t.id.equals(id)))
          .write(
        ProductsCompanion(
          internalCode: Value(internalCode),
          nameAr: Value(nameAr),
          nameEn: Value(nameEn),
          categoryId: Value(categoryId),
          purchasePrice: Value(purchasePrice),
          retailPrice: Value(retailPrice),
          wholesalePrice: Value(wholesalePrice),
          minQuantity: Value(minQuantity),
          updatedAt: Value(DateTime.now()),
        ),
      );

      if (barcode != null && barcode.trim().isNotEmpty) {
        final existingBarcode = await (db.select(db.productBarcodes)
              ..where((t) => t.productId.equals(id) & t.isPrimary.equals(true)))
            .getSingleOrNull();

        if (existingBarcode != null) {
          await (db.update(db.productBarcodes)
                ..where((t) => t.id.equals(existingBarcode.id)))
              .write(ProductBarcodesCompanion(barcode: Value(barcode.trim())));
        } else {
          await db.into(db.productBarcodes).insert(
                ProductBarcodesCompanion.insert(
                  productId: id,
                  barcode: barcode.trim(),
                  isPrimary: const Value(true),
                ),
              );
        }
      }

      return rows > 0;
    });
  }

  static Future<int> deleteProduct(AppDatabase db, int id) {
    return db.transaction(() async {
      await (db.delete(db.productBarcodes)..where((t) => t.productId.equals(id))).go();
      return (db.delete(db.products)..where((t) => t.id.equals(id))).go();
    });
  }

  static Future<Shift?> getActiveShift(AppDatabase db) async {
    return (db.select(db.shifts)..where((t) => t.status.equals('open'))).getSingleOrNull();
  }

  static Future<Map<String, double>> getShiftSummary(AppDatabase db, Shift shift) async {
    final txs = await (db.select(db.treasuryTransactions)
          ..where((t) =>
              t.shiftId.equals(shift.id) |
              (t.createdAt.isBiggerOrEqualValue(shift.openedAt) &
                  (shift.closedAt != null
                      ? t.createdAt.isSmallerOrEqualValue(shift.closedAt!)
                      : const CustomExpression<bool>('1=1')))))
        .get();

    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (final tx in txs) {
      if (tx.type == 'INCOME' || tx.type == 'DEPOSIT') {
        totalIncome += tx.amount;
      } else if (tx.type == 'EXPENSE' || tx.type == 'WITHDRAWAL') {
        totalExpense += tx.amount;
      }
    }

    final netChange = totalIncome - totalExpense;
    final expected = shift.openingBalance + netChange;

    return {
      'opening': shift.openingBalance,
      'income': totalIncome,
      'expense': totalExpense,
      'net': netChange,
      'expected': expected,
    };
  }

  static Future<int> saveSalesInvoice(
    AppDatabase db, {
    required List<PosCartItem> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paid,
    required String paymentMethod,
    int? customerId,
    required int userId,
    int? shiftId,
  }) async {
    return db.transaction(() async {
      int? activeShiftId = shiftId;
      if (activeShiftId == null) {
        final activeShift = await getActiveShift(db);
        activeShiftId = activeShift?.id;
      }

      final invCount = await db.select(db.invoices).get();
      final invoiceNumber = 'INV-${(invCount.length + 1001).toString()}';
      final remaining = (total - paid) > 0 ? (total - paid) : 0.0;

      final invoiceId = await db
          .into(db.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: invoiceNumber,
              customerId: Value(customerId),
              userId: userId,
              shiftId: Value(activeShiftId),
              subtotal: Value(subtotal),
              discount: Value(discount),
              total: Value(total),
              paid: Value(paid),
              remaining: Value(remaining),
              paymentMethod: Value(paymentMethod),
              status: const Value('completed'),
            ),
          );

      for (final item in items) {
        await db
            .into(db.invoiceItems)
            .insert(
              InvoiceItemsCompanion.insert(
                invoiceId: invoiceId,
                productId: item.product.id,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: Value(item.discount),
                total: item.total,
                costPrice: Value(item.product.purchasePrice),
              ),
            );

        final newQty = item.product.currentQuantity - item.quantity;
        await (db.update(db.products)
              ..where((t) => t.id.equals(item.product.id)))
            .write(ProductsCompanion(currentQuantity: Value(newQty)));

        await db
            .into(db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                productId: item.product.id,
                movementType: 'OUT',
                quantity: item.quantity,
                referenceType: const Value('sales_invoice'),
                referenceId: Value(invoiceId),
                userId: userId,
                notes: Value('فاتورة مبيعات #$invoiceNumber'),
              ),
            );
      }

      if (paid > 0) {
        final treasuries = await db.select(db.treasury).get();
        if (treasuries.isNotEmpty) {
          final mainTreasury = treasuries.first;
          final newBalance = mainTreasury.currentBalance + paid;
          await (db.update(db.treasury)
                ..where((t) => t.id.equals(mainTreasury.id)))
              .write(TreasuryCompanion(currentBalance: Value(newBalance)));

          await db
              .into(db.treasuryTransactions)
              .insert(
                TreasuryTransactionsCompanion.insert(
                  treasuryId: mainTreasury.id,
                  shiftId: Value(activeShiftId),
                  type: 'INCOME',
                  amount: paid,
                  description: Value('مبيعات فاتورة #$invoiceNumber'),
                  referenceType: const Value('sales_invoice'),
                  referenceId: Value(invoiceId),
                  userId: userId,
                ),
              );
        }
      }

      if (customerId != null && remaining > 0) {
        final cust = await (db.select(
          db.customers,
        )..where((t) => t.id.equals(customerId))).getSingleOrNull();
        if (cust != null) {
          final newCustBalance = cust.balance + remaining;
          await (db.update(db.customers)..where((t) => t.id.equals(customerId)))
              .write(CustomersCompanion(balance: Value(newCustBalance)));
        }
      }

      return invoiceId;
    });
  }

  static Future<int> savePurchaseInvoice(
    AppDatabase db, {
    required int supplierId,
    required List<PurchaseCartItem> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paid,
    required String paymentMethod,
    required int userId,
    int? shiftId,
  }) async {
    return db.transaction(() async {
      int? activeShiftId = shiftId;
      if (activeShiftId == null) {
        final activeShift = await getActiveShift(db);
        activeShiftId = activeShift?.id;
      }

      final invCount = await db.select(db.purchaseInvoices).get();
      final invoiceNumber = 'PUR-${(invCount.length + 1001).toString()}';
      final remaining = (total - paid) > 0 ? (total - paid) : 0.0;

      final invoiceId = await db
          .into(db.purchaseInvoices)
          .insert(
            PurchaseInvoicesCompanion.insert(
              invoiceNumber: invoiceNumber,
              supplierId: supplierId,
              userId: userId,
              shiftId: Value(activeShiftId),
              subtotal: Value(subtotal),
              discount: Value(discount),
              total: Value(total),
              paid: Value(paid),
              remaining: Value(remaining),
              paymentMethod: Value(paymentMethod),
              status: const Value('completed'),
            ),
          );

      for (final item in items) {
        await db
            .into(db.purchaseItems)
            .insert(
              PurchaseItemsCompanion.insert(
                purchaseInvoiceId: invoiceId,
                productId: item.product.id,
                quantity: item.quantity,
                unitPrice: item.purchasePrice,
                total: item.total,
              ),
            );

        final newQty = item.product.currentQuantity + item.quantity;
        await (db.update(
          db.products,
        )..where((t) => t.id.equals(item.product.id))).write(
          ProductsCompanion(
            currentQuantity: Value(newQty),
            purchasePrice: Value(item.purchasePrice),
            lastPurchasePrice: Value(item.purchasePrice),
          ),
        );

        await db
            .into(db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                productId: item.product.id,
                movementType: 'IN',
                quantity: item.quantity,
                referenceType: const Value('purchase_invoice'),
                referenceId: Value(invoiceId),
                userId: userId,
                notes: Value('فاتورة شراء #$invoiceNumber'),
              ),
            );
      }

      if (paid > 0) {
        final treasuries = await db.select(db.treasury).get();
        if (treasuries.isNotEmpty) {
          final mainTreasury = treasuries.first;
          final newBalance = mainTreasury.currentBalance - paid;
          await (db.update(db.treasury)
                ..where((t) => t.id.equals(mainTreasury.id)))
              .write(TreasuryCompanion(currentBalance: Value(newBalance)));

          await db
              .into(db.treasuryTransactions)
              .insert(
                TreasuryTransactionsCompanion.insert(
                  treasuryId: mainTreasury.id,
                  shiftId: Value(activeShiftId),
                  type: 'EXPENSE',
                  amount: paid,
                  description: Value('مشتريات فاتورة #$invoiceNumber'),
                  referenceType: const Value('purchase_invoice'),
                  referenceId: Value(invoiceId),
                  userId: userId,
                ),
              );
        }
      }

      if (remaining > 0) {
        final supp = await (db.select(
          db.suppliers,
        )..where((t) => t.id.equals(supplierId))).getSingleOrNull();
        if (supp != null) {
          final newSuppBalance = supp.balance + remaining;
          await (db.update(db.suppliers)..where((t) => t.id.equals(supplierId)))
              .write(SuppliersCompanion(balance: Value(newSuppBalance)));
        }
      }

      return invoiceId;
    });
  }

  static Future<void> addStockMovement(
    AppDatabase db, {
    required int productId,
    required String movementType,
    required double quantity,
    required int userId,
    String? notes,
  }) async {
    await db.transaction(() async {
      final prod = await (db.select(
        db.products,
      )..where((t) => t.id.equals(productId))).getSingle();
      double newQty = prod.currentQuantity;
      if (movementType == 'IN') {
        newQty += quantity;
      } else if (movementType == 'OUT') {
        newQty -= quantity;
      } else if (movementType == 'ADJUSTMENT') {
        newQty = quantity;
      }

      await (db.update(db.products)..where((t) => t.id.equals(productId)))
          .write(ProductsCompanion(currentQuantity: Value(newQty)));

      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              productId: productId,
              movementType: movementType,
              quantity: quantity,
              userId: userId,
              notes: Value(notes),
            ),
          );
    });
  }

  static Future<void> updateProductStock({
    required AppDatabase db,
    required int productId,
    required double quantityDelta,
    int userId = 1,
  }) async {
    final type = quantityDelta >= 0 ? 'IN' : 'OUT';
    await addStockMovement(
      db,
      productId: productId,
      movementType: type,
      quantity: quantityDelta.abs(),
      userId: userId,
      notes: 'تعديل مخزون مباشر',
    );
  }

  static Future<void> addTreasuryTransaction(
    AppDatabase db, {
    required String type,
    required double amount,
    required int userId,
    String? description,
    int? categoryId,
    int? shiftId,
  }) async {
    await db.transaction(() async {
      int? activeShiftId = shiftId;
      if (activeShiftId == null) {
        final activeShift = await getActiveShift(db);
        activeShiftId = activeShift?.id;
      }

      final treasuries = await db.select(db.treasury).get();
      if (treasuries.isEmpty) return;
      final mainTreasury = treasuries.first;

      double newBalance = mainTreasury.currentBalance;
      if (type == 'INCOME' || type == 'DEPOSIT') {
        newBalance += amount;
      } else {
        newBalance -= amount;
      }

      await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
          .write(TreasuryCompanion(currentBalance: Value(newBalance)));

      await db
          .into(db.treasuryTransactions)
          .insert(
            TreasuryTransactionsCompanion.insert(
              treasuryId: mainTreasury.id,
              shiftId: Value(activeShiftId),
              type: type,
              amount: amount,
              description: Value(description),
              categoryId: Value(categoryId),
              userId: userId,
            ),
          );
    });
  }

  static Future<int> openShift(
    AppDatabase db, {
    required double openingBalance,
    required int userId,
    String? notes,
  }) async {
    return db.transaction(() async {
      final active = await getActiveShift(db);
      if (active != null) {
        throw Exception('يوجد شيفت مفتوح بالفعل (#${active.id}). يرجى إغلاقه أولاً.');
      }

      final treasuries = await db.select(db.treasury).get();
      int treasuryId = 1;
      if (treasuries.isNotEmpty) {
        treasuryId = treasuries.first.id;
      }

      return db.into(db.shifts).insert(
            ShiftsCompanion.insert(
              userId: userId,
              treasuryId: treasuryId,
              openingBalance: Value(openingBalance),
              status: const Value('open'),
              notes: Value(notes),
            ),
          );
    });
  }

  static Future<void> closeShift(
    AppDatabase db, {
    required int shiftId,
    required double closingBalance,
    String? notes,
  }) async {
    await db.transaction(() async {
      final shift = await (db.select(db.shifts)..where((t) => t.id.equals(shiftId))).getSingle();
      final summary = await getShiftSummary(db, shift);
      final expected = summary['expected'] ?? shift.openingBalance;
      final diff = closingBalance - expected;

      await (db.update(db.shifts)..where((t) => t.id.equals(shiftId))).write(
        ShiftsCompanion(
          closingBalance: Value(closingBalance),
          expectedBalance: Value(expected),
          difference: Value(diff),
          status: const Value('closed'),
          closedAt: Value(DateTime.now()),
          notes: Value(notes),
        ),
      );
    });
  }

  static Future<int> suspendSalesInvoice(
    AppDatabase db, {
    required String invoiceDataJson,
    required int userId,
    String? customerName,
    String? notes,
  }) {
    return db.into(db.suspendedInvoices).insert(
          SuspendedInvoicesCompanion.insert(
            invoiceDataJson: invoiceDataJson,
            userId: userId,
            customerName: Value(customerName),
            notes: Value(notes),
          ),
        );
  }

  static Future<List<SuspendedInvoice>> getSuspendedInvoices(AppDatabase db) {
    return (db.select(db.suspendedInvoices)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  static Future<int> deleteSuspendedInvoice(AppDatabase db, int id) {
    return (db.delete(db.suspendedInvoices)..where((t) => t.id.equals(id))).go();
  }

  static Future<void> clearAllData(AppDatabase db) async {
    await db.transaction(() async {
      await db.delete(db.invoiceItems).go();
      await db.delete(db.invoices).go();
      await db.delete(db.purchaseItems).go();
      await db.delete(db.purchaseInvoices).go();
      await db.delete(db.stockMovements).go();
      await db.delete(db.inventoryCountItems).go();
      await db.delete(db.inventoryCounts).go();
      await db.delete(db.treasuryTransactions).go();
      await db.delete(db.shifts).go();
      await db.delete(db.suspendedInvoices).go();
      await db.delete(db.productBarcodes).go();
      await db.delete(db.productPriceHistory).go();
      await db.delete(db.products).go();
      await db.delete(db.brands).go();
      await db.delete(db.categories).go();
      await db.delete(db.customers).go();
      await db.delete(db.suppliers).go();
      await db.delete(db.partnerWithdrawals).go();
      await db.delete(db.partnerProfits).go();
      await db.delete(db.partners).go();
      await db.delete(db.auditLog).go();

      await db.update(db.treasury).write(const TreasuryCompanion(currentBalance: Value(0.0)));
    });
  }
}



