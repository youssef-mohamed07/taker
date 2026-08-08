import 'package:drift/drift.dart';
import 'user_tables.dart';

/// Product categories
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Brands / manufacturers
class Brands extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Units of measurement
class Units extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get abbreviation => text().withLength(max: 10).nullable()();
}

/// Products master table
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get internalCode => text().withLength(max: 50).nullable()();
  TextColumn get nameAr => text().withLength(min: 1, max: 200)();
  TextColumn get nameEn => text().withLength(max: 200).nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get brandId => integer().nullable().references(Brands, #id)();
  IntColumn get unitId => integer().nullable().references(Units, #id)();
  IntColumn get supplierId => integer().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get location => text().withLength(max: 100).nullable()();
  RealColumn get minQuantity => real().withDefault(const Constant(0))();
  RealColumn get currentQuantity => real().withDefault(const Constant(0))();
  RealColumn get purchasePrice => real().withDefault(const Constant(0))();
  RealColumn get lastPurchasePrice => real().withDefault(const Constant(0))();
  RealColumn get avgPurchasePrice => real().withDefault(const Constant(0))();
  RealColumn get wholesalePrice => real().withDefault(const Constant(0))();
  RealColumn get semiWholesalePrice => real().withDefault(const Constant(0))();
  RealColumn get retailPrice => real().withDefault(const Constant(0))();
  RealColumn get profitMargin => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Product barcodes (one product can have multiple barcodes)
class ProductBarcodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get barcode => text().withLength(min: 1, max: 100)();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {barcode},
  ];
}

/// Price change history
class ProductPriceHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get priceType =>
      text()(); // wholesale, semi_wholesale, retail, purchase
  RealColumn get oldPrice => real()();
  RealColumn get newPrice => real()();
  IntColumn get changedBy => integer().references(Users, #id)();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Product Batches for tracking expiration dates and quantities
class ProductBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
