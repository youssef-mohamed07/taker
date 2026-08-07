import 'package:drift/drift.dart';
import 'user_tables.dart';

/// Audit log for tracking all operations
class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get action => text()(); // CREATE, UPDATE, DELETE
  TextColumn get targetTable => text()();
  IntColumn get recordId => integer().nullable()();
  TextColumn get oldData => text().nullable()();
  TextColumn get newData => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// App settings (key-value store)
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}
