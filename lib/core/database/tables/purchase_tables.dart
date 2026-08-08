import 'package:drift/drift.dart';
import 'product_tables.dart';
import 'user_tables.dart';
import 'sales_tables.dart';

/// Purchase invoices
class PurchaseInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get shiftId => integer().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  RealColumn get paid => real().withDefault(const Constant(0))();
  RealColumn get remaining => real().withDefault(const Constant(0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Purchase line items
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseInvoiceId =>
      integer().references(PurchaseInvoices, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()();
}


/// Purchase Returns
class PurchaseReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get returnNumber => text().unique()();
  IntColumn get invoiceId => integer().nullable().references(PurchaseInvoices, #id)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get shiftId => integer().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Purchase Return Items
class PurchaseReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(PurchaseReturns, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()();
}
