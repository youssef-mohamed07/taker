import 'package:drift/drift.dart';
import 'product_tables.dart';
import 'user_tables.dart';

/// Customers
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().withLength(max: 20).nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0))();
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Suppliers
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().withLength(max: 20).nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Sales invoices
class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
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

/// Invoice line items
class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  RealColumn get costPrice => real().withDefault(const Constant(0))();
}

/// Suspended (parked) invoices
class SuspendedInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceDataJson => text()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get customerName => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}


/// Sales Returns
class SalesReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get returnNumber => text().unique()();
  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get shiftId => integer().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Sales Return Items
class SalesReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(SalesReturns, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()();
}
