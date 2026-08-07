import 'package:drift/drift.dart';

/// Users table
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().withLength(min: 3, max: 50).unique()();
  TextColumn get passwordHash => text()();
  TextColumn get fullName => text().withLength(min: 1, max: 100)();
  TextColumn get role => text()(); // admin, accountant, cashier, storekeeper
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Permissions table
class Permissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get module => text()(); // products, pos, purchases, etc.
  BoolColumn get canView => boolean().withDefault(const Constant(true))();
  BoolColumn get canCreate => boolean().withDefault(const Constant(false))();
  BoolColumn get canEdit => boolean().withDefault(const Constant(false))();
  BoolColumn get canDelete => boolean().withDefault(const Constant(false))();
}
