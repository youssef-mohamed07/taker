import 'package:drift/drift.dart';
import 'product_tables.dart';
import 'user_tables.dart';

/// Stock movement tracking
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get movementType =>
      text()(); // IN, OUT, ADJUSTMENT, DAMAGE, RETURN
  RealColumn get quantity => real()();
  TextColumn get referenceType =>
      text().nullable()(); // invoice, purchase, adjustment
  IntColumn get referenceId => integer().nullable()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Inventory count sessions
class InventoryCounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // FULL, PARTIAL
  TextColumn get status => text().withDefault(const Constant('in_progress'))();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// Individual items in an inventory count
class InventoryCountItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get inventoryCountId =>
      integer().references(InventoryCounts, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get systemQuantity => real()();
  RealColumn get actualQuantity => real().nullable()();
  RealColumn get difference => real().nullable()();
}
