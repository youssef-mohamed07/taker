import 'package:drift/drift.dart';
import 'app_database.dart';

class DatabaseSeeder {
  final AppDatabase db;

  DatabaseSeeder(this.db);

  Future<bool> shouldSeed() async {
    // Check if products table is empty
    final count = await db.customSelect('SELECT COUNT(*) AS c FROM products').getSingle();
    final c = count.read<int>('c');
    return c == 0;
  }

  Future<void> seedDatabase() async {
    // 1. Categories
    final categories = [
      'إلكترونيات',
      'جوالات',
      'أجهزة منزلية',
      'إكسسوارات',
      'ملابس',
      'بقالة'
    ];
    final categoryIds = <int>[];
    for (final cat in categories) {
      final id = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: cat,
        )
      );
      categoryIds.add(id);
    }

    // 2. Brands
    final brands = ['سامسونج', 'أبل', 'إل جي', 'بوش', 'شاومي'];
    final brandIds = <int>[];
    for (final brand in brands) {
      final id = await db.into(db.brands).insert(
        BrandsCompanion.insert(name: brand)
      );
      brandIds.add(id);
    }

    // 3. Customers
    final customerIds = <int>[];
    final customersData = [
      ('محمد أحمد', '01012345678', 'القاهرة'),
      ('شركة الفارس', '01198765432', 'الإسكندرية'),
      ('علي محمود', '01211112222', 'الجيزة'),
    ];
    for (final c in customersData) {
      final id = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          name: c.$1,
          phone: Value(c.$2),
          address: Value(c.$3),
        )
      );
      customerIds.add(id);
    }

    // 4. Suppliers
    final supplierIds = <int>[];
    final suppliersData = [
      ('المورد الذهبي', '01000000001', 'القاهرة'),
      ('شركة التوريدات الحديثة', '01100000002', 'الجيزة'),
    ];
    for (final s in suppliersData) {
      final id = await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(
          name: s.$1,
          phone: Value(s.$2),
          address: Value(s.$3),
        )
      );
      supplierIds.add(id);
    }

    // 5. Products
    final productsData = [
      ('شاشة سامسونج 55 بوصة', 'SAM-55', categoryIds[2], brandIds[0], 12000.0, 14000.0),
      ('آيفون 13 برو', 'AP-13P', categoryIds[1], brandIds[1], 35000.0, 38000.0),
      ('ثلاجة إل جي', 'LG-FR', categoryIds[2], brandIds[2], 25000.0, 27500.0),
      ('سماعة أيربودز', 'AP-AP', categoryIds[3], brandIds[1], 5000.0, 6000.0),
      ('شاومي ريدمي 12', 'MI-12', categoryIds[1], brandIds[4], 6000.0, 7000.0),
    ];
    final productIds = <int>[];
    for (final p in productsData) {
      final id = await db.into(db.products).insert(
        ProductsCompanion.insert(
          nameAr: p.$1,
          internalCode: Value(p.$2),
          categoryId: Value(p.$3),
          brandId: Value(p.$4),
          purchasePrice: Value(p.$5),
          retailPrice: Value(p.$6),
          wholesalePrice: Value(p.$6 * 0.95),
          unitId: const Value(1), // قطعة
          minQuantity: const Value(5.0),
          notes: const Value('منتج تجريبي ممتاز'),
          currentQuantity: const Value(50.0),
        )
      );
      productIds.add(id);
    }

    // 6. Treasury
    // We already have a default treasury with ID 1
    // We will add initial balance
    final past30Days = DateTime.now().subtract(const Duration(days: 30));
    await db.into(db.treasuryTransactions).insert(
      TreasuryTransactionsCompanion.insert(
        treasuryId: 1,
        userId: 1,
        type: 'deposit',
        amount: 100000.0,
        description: const Value('رصيد افتتاحي'),
        createdAt: Value(past30Days),
      )
    );
    await db.customStatement('UPDATE treasury SET current_balance = 100000.0 WHERE id = 1');

    // 7. Dummy Invoices
    for (int i = 0; i < 5; i++) {
      final totalAmount = 14000.0 * (i + 1);
      final pastDate = DateTime.now().subtract(Duration(days: i));
      
      final invId = await db.into(db.invoices).insert(
        InvoicesCompanion.insert(
          invoiceNumber: 'INV-100$i',
          customerId: Value(customerIds[0]),
          userId: 1,
          subtotal: Value(totalAmount),
          discount: const Value(0.0),
          total: Value(totalAmount),
          paid: Value(totalAmount),
          remaining: const Value(0.0),
          paymentMethod: const Value('cash'),
          createdAt: Value(pastDate),
        )
      );
      
      await db.into(db.invoiceItems).insert(
        InvoiceItemsCompanion.insert(
          invoiceId: invId,
          productId: productIds[0],
          quantity: (i + 1).toDouble(),
          unitPrice: 14000.0,
          total: totalAmount,
        )
      );

      // Record in treasury
      await db.into(db.treasuryTransactions).insert(
        TreasuryTransactionsCompanion.insert(
          treasuryId: 1,
          userId: 1,
          type: 'deposit',
          amount: totalAmount,
          referenceId: Value(invId),
          referenceType: const Value('sales_invoice'),
          description: Value('فاتورة مبيعات #INV-100$i'),
          createdAt: Value(pastDate),
        )
      );
      await db.customStatement('UPDATE treasury SET current_balance = current_balance + $totalAmount WHERE id = 1');
    }
  }
}
