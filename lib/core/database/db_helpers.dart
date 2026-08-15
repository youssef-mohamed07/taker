import 'package:drift/drift.dart' as drift;
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
  final DateTime? expiryDate;

  PurchaseCartItem({
    required this.product,
    required this.quantity,
    required this.purchasePrice,
    this.expiryDate,
  });

  double get total => purchasePrice * quantity;
}

class DbHelpers {
  DbHelpers._();

  /// Write an audit log entry. Fire-and-forget safe: errors are swallowed
  /// so auditing never breaks the business flow.
  static Future<void> logAudit(
    AppDatabase db, {
    required int userId,
    required String action,
    required String targetTable,
    int? recordId,
    String? details,
  }) async {
    try {
      await db.into(db.auditLog).insert(
            AuditLogCompanion.insert(
              userId: userId,
              action: action,
              targetTable: targetTable,
              recordId: Value(recordId),
              newData: Value(details),
            ),
          );
    } catch (_) {}
  }

  static Future<int> addCustomer(
    AppDatabase db, {
    required String name,
    String? phone,
    String? address,
    double balance = 0.0,
    double creditLimit = 0.0,
    String? notes,
    int? actorId,
  }) async {
    final id = await db
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
    await logAudit(db, userId: actorId ?? 1, action: 'CREATE', targetTable: 'customers', recordId: id, details: 'إضافة عميل: $name');
    return id;
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

  static Future<int> deleteCustomer(AppDatabase db, int id, {int? actorId}) async {
    final rows = await (db.delete(db.customers)..where((t) => t.id.equals(id))).go();
    await logAudit(db, userId: actorId ?? 1, action: 'DELETE', targetTable: 'customers', recordId: id);
    return rows;
  }

  static Future<int> addSupplier(
    AppDatabase db, {
    required String name,
    String? phone,
    String? address,
    double balance = 0.0,
    String? notes,
    int? actorId,
  }) async {
    final id = await db
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
    await logAudit(db, userId: actorId ?? 1, action: 'CREATE', targetTable: 'suppliers', recordId: id, details: 'إضافة مورد: $name');
    return id;
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

  static Future<int> deleteSupplier(AppDatabase db, int id, {int? actorId}) async {
    final rows = await (db.delete(db.suppliers)..where((t) => t.id.equals(id))).go();
    await logAudit(db, userId: actorId ?? 1, action: 'DELETE', targetTable: 'suppliers', recordId: id);
    return rows;
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
    int? brandId,
    int? unitId,
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
              brandId: Value(brandId),
              unitId: Value(unitId),
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

      await logAudit(db, userId: userId ?? 1, action: 'CREATE', targetTable: 'products', recordId: productId, details: 'إضافة منتج: $nameAr');
      return productId;
    });
  }

  /// Write a price-history row when a product price actually changed.
  static Future<void> logPriceChange(
    AppDatabase db, {
    required int productId,
    required String priceType,
    required double oldPrice,
    required double newPrice,
    required int changedBy,
  }) async {
    if (oldPrice == newPrice) return;
    try {
      await db.into(db.productPriceHistory).insert(
            ProductPriceHistoryCompanion.insert(
              productId: productId,
              priceType: priceType,
              oldPrice: oldPrice,
              newPrice: newPrice,
              changedBy: changedBy,
            ),
          );
    } catch (_) {}
  }

  static Future<bool> updateProduct(
    AppDatabase db, {
    required int id,
    String? internalCode,
    required String nameAr,
    String? nameEn,
    int? categoryId,
    int? brandId,
    int? unitId,
    double purchasePrice = 0,
    double retailPrice = 0,
    double wholesalePrice = 0,
    double minQuantity = 0,
    String? barcode,
    int? actorId,
  }) async {
    return db.transaction(() async {
      final current = await (db.select(db.products)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      final rows = await (db.update(db.products)..where((t) => t.id.equals(id)))
          .write(
        ProductsCompanion(
          internalCode: Value(internalCode),
          nameAr: Value(nameAr),
          nameEn: Value(nameEn),
          categoryId: Value(categoryId),
          brandId: Value(brandId),
          unitId: Value(unitId),
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

      await logAudit(db, userId: actorId ?? 1, action: 'UPDATE', targetTable: 'products', recordId: id, details: 'تعديل منتج: $nameAr');

      if (current != null) {
        await logPriceChange(db, productId: id, priceType: 'purchase', oldPrice: current.purchasePrice, newPrice: purchasePrice, changedBy: actorId ?? 1);
        await logPriceChange(db, productId: id, priceType: 'retail', oldPrice: current.retailPrice, newPrice: retailPrice, changedBy: actorId ?? 1);
        await logPriceChange(db, productId: id, priceType: 'wholesale', oldPrice: current.wholesalePrice, newPrice: wholesalePrice, changedBy: actorId ?? 1);
      }
      return rows > 0;
    });
  }

  static Future<int> deleteProduct(AppDatabase db, int id, {int? actorId}) {
    return db.transaction(() async {
      await (db.delete(db.productBarcodes)..where((t) => t.productId.equals(id))).go();
      await (db.delete(db.stockMovements)..where((t) => t.productId.equals(id))).go();
      await (db.delete(db.inventoryCountItems)..where((t) => t.productId.equals(id))).go();
      await (db.delete(db.invoiceItems)..where((t) => t.productId.equals(id))).go();
      await (db.delete(db.salesReturnItems)..where((t) => t.productId.equals(id))).go();
      await (db.delete(db.purchaseItems)..where((t) => t.productId.equals(id))).go();
      await (db.delete(db.purchaseReturnItems)..where((t) => t.productId.equals(id))).go();
      await logAudit(db, userId: actorId ?? 1, action: 'DELETE', targetTable: 'products', recordId: id);
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

    // Breakdown per payment channel (cash drawer vs card vs fawry)
    double incomeCash = 0, incomeCard = 0, incomeFawry = 0;
    double expenseCash = 0, expenseCard = 0, expenseFawry = 0;
    for (final tx in txs) {
      final isIn = tx.type == 'INCOME' || tx.type == 'DEPOSIT';
      final pm = tx.paymentMethod ?? 'cash';
      if (pm == 'card') {
        if (isIn) { incomeCard += tx.amount; } else { expenseCard += tx.amount; }
      } else if (pm == 'fawry') {
        if (isIn) { incomeFawry += tx.amount; } else { expenseFawry += tx.amount; }
      } else {
        if (isIn) { incomeCash += tx.amount; } else { expenseCash += tx.amount; }
      }
    }

    return {
      'opening': shift.openingBalance,
      'income': totalIncome,
      'expense': totalExpense,
      'net': netChange,
      'expected': expected,
      'income_cash': incomeCash,
      'income_card': incomeCard,
      'income_fawry': incomeFawry,
      'expense_cash': expenseCash,
      'expense_card': expenseCard,
      'expense_fawry': expenseFawry,
      'expected_cash': shift.openingBalance + incomeCash - expenseCash,
    };
  }

  /// Wallet balances: cash drawer (canonical treasury balance) plus derived
  /// card / fawry wallets computed from their transactions.
  static Future<Map<String, double>> getWalletBalances(AppDatabase db) async {
    double cash = 0;
    final treasuries = await db.select(db.treasury).get();
    if (treasuries.isNotEmpty) cash = treasuries.first.currentBalance;

    final txs = await db.select(db.treasuryTransactions).get();
    double card = 0, fawry = 0;
    for (final tx in txs) {
      final sign = (tx.type == 'INCOME' || tx.type == 'DEPOSIT') ? 1.0 : -1.0;
      if (tx.paymentMethod == 'card') {
        card += sign * tx.amount;
      } else if (tx.paymentMethod == 'fawry') {
        fawry += sign * tx.amount;
      }
    }
    return {'cash': cash, 'card': card, 'fawry': fawry};
  }

  /// Move money from the card/fawry wallet into the cash drawer.
  static Future<void> transferWalletToDrawer(
    AppDatabase db, {
    required String fromMethod,
    required double amount,
    required int userId,
    String? notes,
  }) async {
    if (fromMethod != 'card' && fromMethod != 'fawry') {
      throw Exception('التحويل متاح من محفظة الكارت أو فوري فقط');
    }
    await db.transaction(() async {
      final treasuries = await db.select(db.treasury).get();
      if (treasuries.isEmpty) return;
      final mainTreasury = treasuries.first;
      final activeShift = await getActiveShift(db);
      final label = fromMethod == 'card' ? 'الكارت' : 'فوري';

      // Money leaves the wallet (derived balance goes down)
      await db.into(db.treasuryTransactions).insert(
            TreasuryTransactionsCompanion.insert(
              treasuryId: mainTreasury.id,
              shiftId: Value(activeShift?.id),
              type: 'WITHDRAWAL',
              amount: amount,
              description: Value(notes ?? 'توريد من $label للدرج'),
              referenceType: const Value('transfer'),
              userId: userId,
              paymentMethod: Value(fromMethod),
            ),
          );

      // Money enters the drawer (canonical balance goes up)
      await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
          .write(TreasuryCompanion(currentBalance: Value(mainTreasury.currentBalance + amount)));
      await db.into(db.treasuryTransactions).insert(
            TreasuryTransactionsCompanion.insert(
              treasuryId: mainTreasury.id,
              shiftId: Value(activeShift?.id),
              type: 'DEPOSIT',
              amount: amount,
              description: Value(notes ?? 'توريد من $label للدرج'),
              referenceType: const Value('transfer'),
              userId: userId,
              paymentMethod: const Value('cash'),
            ),
          );
      await logAudit(db, userId: userId, action: 'TRANSFER', targetTable: 'treasury_transactions', details: 'توريد $amount من $label للدرج');
    });
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
        // FIFO Batch Deduction Logic
        double remainingQtyToDeduct = item.quantity;
        
        // Fetch batches for this product ordered by expiry date (oldest first)
        final batches = await (db.select(db.productBatches)
              ..where((t) => t.productId.equals(item.product.id))
              ..where((t) => t.quantity.isBiggerThanValue(0))
              ..orderBy([(t) => OrderingTerm.asc(t.expiryDate)]))
            .get();

        if (batches.isEmpty) {
          // No batches found (e.g. old stock), insert normally
          await db.into(db.invoiceItems).insert(
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
        } else {
          for (final batch in batches) {
            if (remainingQtyToDeduct <= 0) break;
            
            final qtyFromBatch = batch.quantity >= remainingQtyToDeduct 
                ? remainingQtyToDeduct 
                : batch.quantity;
            
            // Deduct from batch
            await (db.update(db.productBatches)..where((t) => t.id.equals(batch.id)))
                .write(ProductBatchesCompanion(quantity: Value(batch.quantity - qtyFromBatch)));
                
            // Insert invoice item for this specific batch chunk
            final chunkTotal = (item.unitPrice * qtyFromBatch) - (item.discount * (qtyFromBatch / item.quantity));
            await db.into(db.invoiceItems).insert(
              InvoiceItemsCompanion.insert(
                invoiceId: invoiceId,
                productId: item.product.id,
                quantity: qtyFromBatch,
                unitPrice: item.unitPrice,
                discount: Value(item.discount * (qtyFromBatch / item.quantity)),
                total: chunkTotal,
                costPrice: Value(item.product.purchasePrice),
                
              ),
            );
            
            remainingQtyToDeduct -= qtyFromBatch;
          }
          
          // If there's still quantity remaining but all batches are exhausted
          if (remainingQtyToDeduct > 0) {
            final chunkTotal = (item.unitPrice * remainingQtyToDeduct) - (item.discount * (remainingQtyToDeduct / item.quantity));
            await db.into(db.invoiceItems).insert(
              InvoiceItemsCompanion.insert(
                invoiceId: invoiceId,
                productId: item.product.id,
                quantity: remainingQtyToDeduct,
                unitPrice: item.unitPrice,
                discount: Value(item.discount * (remainingQtyToDeduct / item.quantity)),
                total: chunkTotal,
                costPrice: Value(item.product.purchasePrice),
              ),
            );
          }
        }

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
          // Non-cash channels (card/fawry) accrue in their wallets, not the drawer
          if (paymentMethod == 'cash') {
            final newBalance = mainTreasury.currentBalance + paid;
            await (db.update(db.treasury)
                  ..where((t) => t.id.equals(mainTreasury.id)))
                .write(TreasuryCompanion(currentBalance: Value(newBalance)));
          }

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
                  paymentMethod: Value(paymentMethod),
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

      await logAudit(db, userId: userId, action: 'CREATE', targetTable: 'invoices', recordId: invoiceId, details: 'فاتورة مبيعات #$invoiceNumber بإجمالي $total');
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

        // Create a stock batch so FIFO deduction & expiration alerts work.
        await db.into(db.productBatches).insert(
              ProductBatchesCompanion.insert(
                productId: item.product.id,
                quantity: Value(item.quantity),
                expiryDate: Value(item.expiryDate),
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

        await logPriceChange(
          db,
          productId: item.product.id,
          priceType: 'purchase',
          oldPrice: item.product.purchasePrice,
          newPrice: item.purchasePrice,
          changedBy: userId,
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
          if (paymentMethod == 'cash') {
            final newBalance = mainTreasury.currentBalance - paid;
            await (db.update(db.treasury)
                  ..where((t) => t.id.equals(mainTreasury.id)))
                .write(TreasuryCompanion(currentBalance: Value(newBalance)));
          }

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
                  paymentMethod: Value(paymentMethod),
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

      await logAudit(db, userId: userId, action: 'CREATE', targetTable: 'purchase_invoices', recordId: invoiceId, details: 'فاتورة مشتريات #$invoiceNumber بإجمالي $total');
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
      await logAudit(db, userId: userId, action: 'STOCK', targetTable: 'stock_movements', recordId: productId, details: 'حركة مخزون $movementType كمية $quantity');
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
    String paymentMethod = 'cash',
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

      // Only cash moves touch the drawer balance; card/fawry stay in wallets
      if (paymentMethod == 'cash') {
        double newBalance = mainTreasury.currentBalance;
        if (type == 'INCOME' || type == 'DEPOSIT') {
          newBalance += amount;
        } else {
          newBalance -= amount;
        }
        await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
            .write(TreasuryCompanion(currentBalance: Value(newBalance)));
      }

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
              paymentMethod: Value(paymentMethod),
            ),
          );
      await logAudit(db, userId: userId, action: type, targetTable: 'treasury_transactions', details: 'معاملة خزنة $type بمبلغ $amount ($paymentMethod)');
    });
  }

  static Future<int> openShift(
    AppDatabase db, {
    required double openingBalance,
    required int userId,
    String? notes,
    String? companionNames,
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

      final shiftId = await db.into(db.shifts).insert(
            ShiftsCompanion.insert(
              userId: userId,
              treasuryId: treasuryId,
              openingBalance: Value(openingBalance),
              status: const Value('open'),
              notes: Value(notes),
              companionNames: Value(companionNames),
            ),
          );
      await logAudit(db, userId: userId, action: 'SHIFT_OPEN', targetTable: 'shifts', recordId: shiftId, details: 'فتح شيفت برصيد $openingBalance');
      return shiftId;
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
      await logAudit(db, userId: shift.userId, action: 'SHIFT_CLOSE', targetTable: 'shifts', recordId: shiftId, details: 'إغلاق شيفت برصيد $closingBalance');
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

  static Future<void> clearAllData(AppDatabase db, {int? actorId}) async {
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
      await logAudit(db, userId: actorId ?? 1, action: 'RESET', targetTable: 'all', details: 'تصفير كافة بيانات النظام');
    });
  }

  // ---------------------------------------------------------------------------
  // Customer & Supplier Debts
  // ---------------------------------------------------------------------------

  static Future<void> receiveCustomerPayment(
    AppDatabase db, {
    required int customerId,
    required double amount,
    required int userId,
    String? notes,
    String paymentMethod = 'cash',
  }) async {
    await db.transaction(() async {
      // 1. Get Customer
      final customer = await (db.select(db.customers)..where((t) => t.id.equals(customerId))).getSingle();
      
      // 2. Reduce Customer Balance (Balance means what they owe us)
      final newBalance = customer.balance - amount;
      await (db.update(db.customers)..where((t) => t.id.equals(customerId)))
          .write(CustomersCompanion(balance: Value(newBalance)));
          
      // 3. Add to Treasury
      final treasuries = await db.select(db.treasury).get();
      if (treasuries.isNotEmpty) {
        final mainTreasury = treasuries.first;
        if (paymentMethod == 'cash') {
          final newTreasuryBalance = mainTreasury.currentBalance + amount;
          await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
              .write(TreasuryCompanion(currentBalance: Value(newTreasuryBalance)));
        }
            
        // 4. Log Transaction
        final activeShift = await getActiveShift(db);
        await db.into(db.treasuryTransactions).insert(
          TreasuryTransactionsCompanion.insert(
            treasuryId: mainTreasury.id,
            shiftId: Value(activeShift?.id),
            type: 'INCOME',
            amount: amount,
            description: Value(notes ?? 'تحصيل مديونية من العميل: ${customer.name}'),
            referenceType: const Value('customer_payment'),
            referenceId: Value(customerId),
            userId: userId,
            paymentMethod: Value(paymentMethod),
          )
        );
      }
      await logAudit(db, userId: userId, action: 'PAYMENT', targetTable: 'customers', recordId: customerId, details: 'تحصيل مديونية من ${customer.name} بمبلغ $amount ($paymentMethod)');
    });
  }

  static Future<void> paySupplierDebt(
    AppDatabase db, {
    required int supplierId,
    required double amount,
    required int userId,
    String? notes,
    String paymentMethod = 'cash',
  }) async {
    await db.transaction(() async {
      // 1. Get Supplier
      final supplier = await (db.select(db.suppliers)..where((t) => t.id.equals(supplierId))).getSingle();
      
      // 2. Reduce Supplier Balance (Balance means what we owe them)
      final newBalance = supplier.balance - amount;
      await (db.update(db.suppliers)..where((t) => t.id.equals(supplierId)))
          .write(SuppliersCompanion(balance: Value(newBalance)));
          
      // 3. Deduct from Treasury
      final treasuries = await db.select(db.treasury).get();
      if (treasuries.isNotEmpty) {
        final mainTreasury = treasuries.first;
        if (paymentMethod == 'cash') {
          final newTreasuryBalance = mainTreasury.currentBalance - amount;
          await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
              .write(TreasuryCompanion(currentBalance: Value(newTreasuryBalance)));
        }
            
        // 4. Log Transaction
        final activeShift = await getActiveShift(db);
        await db.into(db.treasuryTransactions).insert(
          TreasuryTransactionsCompanion.insert(
            treasuryId: mainTreasury.id,
            shiftId: Value(activeShift?.id),
            type: 'EXPENSE',
            amount: amount,
            description: Value(notes ?? 'سداد مديونية للمورد: ${supplier.name}'),
            referenceType: const Value('supplier_payment'),
            referenceId: Value(supplierId),
            userId: userId,
            paymentMethod: Value(paymentMethod),
          )
        );
      }
      await logAudit(db, userId: userId, action: 'PAYMENT', targetTable: 'suppliers', recordId: supplierId, details: 'سداد مديونية للمورد ${supplier.name} بمبلغ $amount');
    });
  }

  // ---------------------------------------------------------------------------
  // Returns
  // ---------------------------------------------------------------------------

  static Future<void> processSalesReturn(
    AppDatabase db, {
    required int? invoiceId,
    required int? customerId,
    required double totalAmount,
    required String paymentMethod,
    required List<SalesReturnItemsCompanion> items,
    required int userId,
    String? notes,
  }) async {
    await db.transaction(() async {
      // 1. Create Return record
      final returnNumber = 'SR-${DateTime.now().millisecondsSinceEpoch}';
      final activeShift = await getActiveShift(db);
      
      final returnId = await db.into(db.salesReturns).insert(
        SalesReturnsCompanion.insert(
          returnNumber: returnNumber,
          invoiceId: Value(invoiceId),
          customerId: Value(customerId),
          userId: userId,
          shiftId: Value(activeShift?.id),
          total: drift.Value(totalAmount),
          paymentMethod: drift.Value(paymentMethod),
          notes: Value(notes),
        )
      );

      // 2. Process Items (Increase Stock)
      for (final item in items) {
        await db.into(db.salesReturnItems).insert(
          item.copyWith(returnId: Value(returnId))
        );
        
        final productId = item.productId.value;
        final qty = item.quantity.value;
        
        final prod = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
        await (db.update(db.products)..where((t) => t.id.equals(productId)))
            .write(ProductsCompanion(currentQuantity: Value(prod.currentQuantity + qty)));
            
        await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: productId,
            movementType: 'IN',
            quantity: qty,
            userId: userId,
            notes: Value('مرتجع مبيعات رقم $returnNumber'),
          )
        );
      }

      // 3. Financials
      if (paymentMethod != 'credit') {
        final treasuries = await db.select(db.treasury).get();
        if (treasuries.isNotEmpty) {
          final mainTreasury = treasuries.first;
          if (paymentMethod == 'cash') {
            await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
                .write(TreasuryCompanion(currentBalance: Value(mainTreasury.currentBalance - totalAmount)));
          }
              
          await db.into(db.treasuryTransactions).insert(
            TreasuryTransactionsCompanion.insert(
              treasuryId: mainTreasury.id,
              shiftId: Value(activeShift?.id),
              type: 'EXPENSE',
              amount: totalAmount,
              description: Value('رد نقدي لمرتجع مبيعات $returnNumber'),
              referenceType: const Value('sales_return'),
              referenceId: Value(returnId),
              userId: userId,
              paymentMethod: Value(paymentMethod),
            )
          );
        }
      } else if (paymentMethod == 'credit' && customerId != null) {
        final customer = await (db.select(db.customers)..where((t) => t.id.equals(customerId))).getSingle();
        await (db.update(db.customers)..where((t) => t.id.equals(customerId)))
            .write(CustomersCompanion(balance: Value(customer.balance - totalAmount)));
      }

      await logAudit(db, userId: userId, action: 'RETURN', targetTable: 'sales_returns', recordId: returnId, details: 'مرتجع مبيعات $returnNumber بمبلغ $totalAmount');
    });
  }

  static Future<void> processPurchaseReturn(
    AppDatabase db, {
    required int? invoiceId,
    required int? supplierId,
    required double totalAmount,
    required String paymentMethod,
    required List<PurchaseReturnItemsCompanion> items,
    required int userId,
    String? notes,
  }) async {
    await db.transaction(() async {
      // 1. Create Return record
      final returnNumber = 'PR-${DateTime.now().millisecondsSinceEpoch}';
      final activeShift = await getActiveShift(db);
      
      final returnId = await db.into(db.purchaseReturns).insert(
        PurchaseReturnsCompanion.insert(
          returnNumber: returnNumber,
          invoiceId: Value(invoiceId),
          supplierId: Value(supplierId),
          userId: userId,
          shiftId: Value(activeShift?.id),
          total: drift.Value(totalAmount),
          paymentMethod: drift.Value(paymentMethod),
          notes: Value(notes),
        )
      );

      // 2. Process Items (Decrease Stock)
      for (final item in items) {
        await db.into(db.purchaseReturnItems).insert(
          item.copyWith(returnId: Value(returnId))
        );
        
        final productId = item.productId.value;
        final qty = item.quantity.value;
        
        final prod = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
        await (db.update(db.products)..where((t) => t.id.equals(productId)))
            .write(ProductsCompanion(currentQuantity: Value(prod.currentQuantity - qty)));
            
        await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: productId,
            movementType: 'OUT',
            quantity: qty,
            userId: userId,
            notes: Value('مرتجع مشتريات رقم $returnNumber'),
          )
        );
      }

      // 3. Financials
      if (paymentMethod != 'credit') {
        final treasuries = await db.select(db.treasury).get();
        if (treasuries.isNotEmpty) {
          final mainTreasury = treasuries.first;
          if (paymentMethod == 'cash') {
            await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
                .write(TreasuryCompanion(currentBalance: Value(mainTreasury.currentBalance + totalAmount)));
          }
              
          await db.into(db.treasuryTransactions).insert(
            TreasuryTransactionsCompanion.insert(
              treasuryId: mainTreasury.id,
              shiftId: Value(activeShift?.id),
              type: 'INCOME',
              amount: totalAmount,
              description: Value('استرداد نقدي لمرتجع مشتريات $returnNumber'),
              referenceType: const Value('purchase_return'),
              referenceId: Value(returnId),
              userId: userId,
              paymentMethod: Value(paymentMethod),
            )
          );
        }
      } else if (paymentMethod == 'credit' && supplierId != null) {
        final supplier = await (db.select(db.suppliers)..where((t) => t.id.equals(supplierId))).getSingle();
        await (db.update(db.suppliers)..where((t) => t.id.equals(supplierId)))
            .write(SuppliersCompanion(balance: Value(supplier.balance - totalAmount)));
      }

      await logAudit(db, userId: userId, action: 'RETURN', targetTable: 'purchase_returns', recordId: returnId, details: 'مرتجع مشتريات $returnNumber بمبلغ $totalAmount');
    });
  }

  static Future<void> voidPurchaseInvoice(AppDatabase db, int invoiceId) async {
    return db.transaction(() async {
      // 1. Get the invoice
      final invoice = await (db.select(db.purchaseInvoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
      if (invoice == null || invoice.status == 'voided') return;

      // 2. Mark as voided
      await (db.update(db.purchaseInvoices)..where((t) => t.id.equals(invoiceId)))
          .write(PurchaseInvoicesCompanion(status: const Value('voided')));

      // 3. Reverse stock movements and quantities
      final items = await (db.select(db.purchaseItems)..where((t) => t.purchaseInvoiceId.equals(invoiceId))).get();
      for (final item in items) {
        // Remove quantity from product
        final product = await (db.select(db.products)..where((t) => t.id.equals(item.productId))).getSingle();
        await (db.update(db.products)..where((t) => t.id.equals(product.id)))
            .write(ProductsCompanion(currentQuantity: Value(product.currentQuantity - item.quantity)));

        // If batch system used, we should ideally void the batch, but for now we adjust stock.
        
        // Log stock movement
        await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: product.id,
            movementType: 'OUT',
            quantity: item.quantity,
            referenceType: const Value('void_purchase_invoice'),
            referenceId: Value(invoiceId),
            userId: invoice.userId,
            notes: Value('إلغاء فاتورة مشتريات #${invoice.invoiceNumber}'),
          ),
        );
      }

      // 4. Reverse treasury if paid (refund the money paid to supplier)
      if (invoice.paid > 0) {
        final treasuries = await db.select(db.treasury).get();
        if (treasuries.isNotEmpty) {
          final mainTreasury = treasuries.first;
          final refundMethod = (invoice.paymentMethod == 'card' || invoice.paymentMethod == 'fawry')
              ? invoice.paymentMethod
              : 'cash';
          if (refundMethod == 'cash') {
            await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
                .write(TreasuryCompanion(currentBalance: Value(mainTreasury.currentBalance + invoice.paid)));
          }

          await db.into(db.treasuryTransactions).insert(
            TreasuryTransactionsCompanion.insert(
              treasuryId: mainTreasury.id,
              shiftId: Value(invoice.shiftId),
              type: 'INCOME', // refund
              amount: invoice.paid,
              description: Value('استرداد نقدية لإلغاء فاتورة مشتريات #${invoice.invoiceNumber}'),
              referenceType: const Value('void_purchase_invoice'),
              referenceId: Value(invoiceId),
              userId: invoice.userId,
              paymentMethod: Value(refundMethod),
            ),
          );
        }
      }

      // 5. Reverse supplier balance if credit
      if (invoice.remaining > 0) {
        final supplier = await (db.select(db.suppliers)..where((t) => t.id.equals(invoice.supplierId))).getSingleOrNull();
        if (supplier != null) {
          await (db.update(db.suppliers)..where((t) => t.id.equals(supplier.id)))
              .write(SuppliersCompanion(balance: Value(supplier.balance - invoice.remaining)));
        }
      }

      await logAudit(db, userId: invoice.userId, action: 'VOID', targetTable: 'purchase_invoices', recordId: invoiceId, details: 'إلغاء فاتورة مشتريات #${invoice.invoiceNumber}');
    });
  }

  static Future<void> voidSalesInvoice(AppDatabase db, int invoiceId) async {
    return db.transaction(() async {
      // 1. Get the invoice
      final invoice = await (db.select(db.invoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
      if (invoice == null || invoice.status == 'voided') return;

      // 2. Mark as voided
      await (db.update(db.invoices)..where((t) => t.id.equals(invoiceId)))
          .write(InvoicesCompanion(status: const Value('voided')));

      // 3. Reverse stock movements and quantities
      final items = await (db.select(db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
      for (final item in items) {
        // Add quantity back to product
        final product = await (db.select(db.products)..where((t) => t.id.equals(item.productId))).getSingle();
        await (db.update(db.products)..where((t) => t.id.equals(product.id)))
            .write(ProductsCompanion(currentQuantity: Value(product.currentQuantity + item.quantity)));

        // If batch system used, add back to batch or create a new returned batch
        

        // Log stock movement
        await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: product.id,
            movementType: 'IN',
            quantity: item.quantity,
            referenceType: const Value('void_sales_invoice'),
            referenceId: Value(invoiceId),
            userId: invoice.userId,
            notes: Value('إلغاء فاتورة مبيعات #${invoice.invoiceNumber}'),
          ),
        );
      }

      // 4. Reverse treasury if paid
      if (invoice.paid > 0) {
        final treasuries = await db.select(db.treasury).get();
        if (treasuries.isNotEmpty) {
          final mainTreasury = treasuries.first;
          final refundMethod = (invoice.paymentMethod == 'card' || invoice.paymentMethod == 'fawry')
              ? invoice.paymentMethod
              : 'cash';
          if (refundMethod == 'cash') {
            await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
                .write(TreasuryCompanion(currentBalance: Value(mainTreasury.currentBalance - invoice.paid)));
          }

          await db.into(db.treasuryTransactions).insert(
            TreasuryTransactionsCompanion.insert(
              treasuryId: mainTreasury.id,
              shiftId: Value(invoice.shiftId),
              type: 'EXPENSE',
              amount: invoice.paid,
              description: Value('استرداد نقدية لإلغاء فاتورة #${invoice.invoiceNumber}'),
              referenceType: const Value('void_sales_invoice'),
              referenceId: Value(invoiceId),
              userId: invoice.userId,
              paymentMethod: Value(refundMethod),
            ),
          );
        }
      }

      // 5. Reverse customer balance if credit
      if (invoice.customerId != null && invoice.remaining > 0) {
        final cust = await (db.select(db.customers)..where((t) => t.id.equals(invoice.customerId!))).getSingleOrNull();
        if (cust != null) {
          await (db.update(db.customers)..where((t) => t.id.equals(cust.id)))
              .write(CustomersCompanion(balance: Value(cust.balance - invoice.remaining)));
        }
      }

      await logAudit(db, userId: invoice.userId, action: 'VOID', targetTable: 'invoices', recordId: invoiceId, details: 'إلغاء فاتورة مبيعات #${invoice.invoiceNumber}');
    });
  }

  // ---------------------------------------------------------------------------
  // Workers & Salaries
  // ---------------------------------------------------------------------------

  static Future<int> addWorker(
    AppDatabase db, {
    required String name,
    String? phone,
    double dailyWage = 0,
    String? notes,
    int? actorId,
  }) async {
    final id = await db.into(db.workers).insert(
          WorkersCompanion.insert(
            name: name,
            phone: Value(phone),
            dailyWage: Value(dailyWage),
            notes: Value(notes),
          ),
        );
    await logAudit(db, userId: actorId ?? 1, action: 'CREATE', targetTable: 'workers', recordId: id, details: 'إضافة عامل: $name');
    return id;
  }

  static Future<bool> updateWorker(
    AppDatabase db, {
    required int id,
    required String name,
    String? phone,
    double dailyWage = 0,
    String? notes,
    required bool isActive,
    int? actorId,
  }) async {
    final rows = await (db.update(db.workers)..where((t) => t.id.equals(id))).write(
      WorkersCompanion(
        name: Value(name),
        phone: Value(phone),
        dailyWage: Value(dailyWage),
        notes: Value(notes),
        isActive: Value(isActive),
      ),
    );
    await logAudit(db, userId: actorId ?? 1, action: 'UPDATE', targetTable: 'workers', recordId: id, details: 'تعديل بيانات العامل: $name');
    return rows > 0;
  }

  /// Pay a worker: records the salary payment, deducts from the chosen
  /// channel and logs an EXPENSE under the رواتب category.
  static Future<int> payWorkerSalary(
    AppDatabase db, {
    required int workerId,
    required double amount,
    required int userId,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    return db.transaction(() async {
      final worker = await (db.select(db.workers)..where((t) => t.id.equals(workerId))).getSingle();

      final paymentId = await db.into(db.salaryPayments).insert(
            SalaryPaymentsCompanion.insert(
              workerId: workerId,
              amount: amount,
              paymentMethod: Value(paymentMethod),
              notes: Value(notes),
              userId: userId,
            ),
          );

      final treasuries = await db.select(db.treasury).get();
      if (treasuries.isNotEmpty) {
        final mainTreasury = treasuries.first;
        final activeShift = await getActiveShift(db);

        // Resolve the salaries expense category (رواتب)
        final categories = await db.select(db.expenseCategories).get();
        final salaryCategory = categories.where((c) => c.name == 'رواتب').firstOrNull;

        if (paymentMethod == 'cash') {
          await (db.update(db.treasury)..where((t) => t.id.equals(mainTreasury.id)))
              .write(TreasuryCompanion(currentBalance: Value(mainTreasury.currentBalance - amount)));
        }

        await db.into(db.treasuryTransactions).insert(
              TreasuryTransactionsCompanion.insert(
                treasuryId: mainTreasury.id,
                shiftId: Value(activeShift?.id),
                type: 'EXPENSE',
                amount: amount,
                description: Value('قبض العامل: ${worker.name}${notes != null && notes.isNotEmpty ? ' - $notes' : ''}'),
                referenceType: const Value('salary_payment'),
                referenceId: Value(paymentId),
                categoryId: Value(salaryCategory?.id),
                userId: userId,
                paymentMethod: Value(paymentMethod),
              ),
            );
      }
      await logAudit(db, userId: userId, action: 'SALARY', targetTable: 'salary_payments', recordId: paymentId, details: 'قبض للعامل ${worker.name} بمبلغ $amount ($paymentMethod)');
      return paymentId;
    });
  }

  // ==========================================
  // FAWRY MANAGEMENT
  // ==========================================

  static Future<FawryMachineData> getFawryBalance(AppDatabase db) async {
    final query = db.select(db.fawryMachine);
    final results = await query.get();
    if (results.isEmpty) {
      final id = await db.into(db.fawryMachine).insert(
            FawryMachineCompanion.insert(),
          );
      return (await (db.select(db.fawryMachine)..where((t) => t.id.equals(id))).getSingle());
    }
    return results.first;
  }

  static Stream<FawryMachineData> watchFawryBalance(AppDatabase db) {
    return db.select(db.fawryMachine).watchSingleOrNull().map((event) {
      if (event == null) {
        getFawryBalance(db);
        return FawryMachineData(id: 1, digitalBalance: 0, cashCollected: 0, totalProfits: 0, updatedAt: DateTime.now()) as dynamic;
      }
      return event;
    });
  }

  static Stream<List<FawryTransaction>> watchFawryTransactions(AppDatabase db) {
    return (db.select(db.fawryTransactions)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  static Future<void> executeFawryService(AppDatabase db, {
    required double customerPaid,
    required double machineDeducted,
    String? description,
    int? userId,
  }) async {
    await db.transaction(() async {
      final balance = await getFawryBalance(db);
      final profit = customerPaid - machineDeducted;

      await (db.update(db.fawryMachine)..where((t) => t.id.equals(balance.id))).write(
        FawryMachineCompanion(
          digitalBalance: Value(balance.digitalBalance - machineDeducted),
          cashCollected: Value(balance.cashCollected + customerPaid),
          totalProfits: Value(balance.totalProfits + profit),
        ),
      );

      await db.into(db.fawryTransactions).insert(
            FawryTransactionsCompanion.insert(
              type: 'service',
              amount: -machineDeducted,
              customerPaid: Value(customerPaid),
              profit: Value(profit),
              description: Value(description),
              userId: Value(userId),
            ),
          );
    });
  }

  static Future<void> rechargeFawryMachine(AppDatabase db, {
    required double amount,
    String? description,
    int? userId,
  }) async {
    await db.transaction(() async {
      final balance = await getFawryBalance(db);

      await (db.update(db.fawryMachine)..where((t) => t.id.equals(balance.id))).write(
        FawryMachineCompanion(
          digitalBalance: Value(balance.digitalBalance + amount),
          cashCollected: Value(balance.cashCollected - amount),
        ),
      );

      await db.into(db.fawryTransactions).insert(
            FawryTransactionsCompanion.insert(
              type: 'recharge',
              amount: amount,
              description: Value(description),
              userId: Value(userId),
            ),
          );

      await addTreasuryTransaction(
        db,
        type: 'EXPENSE',
        amount: amount,
        description: 'شحن رصيد ماكينة فوري: ${description ?? ""}',
        paymentMethod: 'cash',
        userId: userId ?? 1,
      );
    });
  }

  static Future<void> deleteFawryTransaction(AppDatabase db, int txId) async {
    await db.transaction(() async {
      final tx = await (db.select(db.fawryTransactions)..where((t) => t.id.equals(txId))).getSingleOrNull();
      if (tx == null) return;

      final balance = await getFawryBalance(db);

      if (tx.type == 'service') {
        await (db.update(db.fawryMachine)..where((t) => t.id.equals(balance.id))).write(
          FawryMachineCompanion(
            digitalBalance: Value(balance.digitalBalance - tx.amount),
            cashCollected: Value(balance.cashCollected - (tx.customerPaid ?? 0)),
            totalProfits: Value(balance.totalProfits - tx.profit),
          ),
        );
      } else if (tx.type == 'recharge') {
        await (db.update(db.fawryMachine)..where((t) => t.id.equals(balance.id))).write(
          FawryMachineCompanion(
            digitalBalance: Value(balance.digitalBalance - tx.amount),
            cashCollected: Value(balance.cashCollected + tx.amount),
          ),
        );
      }

      await (db.delete(db.fawryTransactions)..where((t) => t.id.equals(txId))).go();
    });
  }

}
