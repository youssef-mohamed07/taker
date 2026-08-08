import 'package:drift/drift.dart';
import 'user_tables.dart';

/// Treasury (cash register / safe)
class Treasury extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get currentBalance => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Treasury transactions
class TreasuryTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get treasuryId => integer().references(Treasury, #id)();
  IntColumn get shiftId => integer().nullable()();
  TextColumn get type => text()(); // INCOME, EXPENSE, DEPOSIT, WITHDRAWAL
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  TextColumn get referenceType => text().nullable()();
  IntColumn get referenceId => integer().nullable()();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Expense categories
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

/// Work shifts
class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get treasuryId => integer().references(Treasury, #id)();
  RealColumn get openingBalance => real().withDefault(const Constant(0))();
  RealColumn get closingBalance => real().nullable()();
  RealColumn get expectedBalance => real().nullable()();
  RealColumn get difference => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get companionNames => text().nullable()();
}

/// Partners
class Partners extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get sharePercentage => real()();
  RealColumn get capital => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Partner withdrawals
class PartnerWithdrawals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get partnerId => integer().references(Partners, #id)();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Partner profit distributions
class PartnerProfits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get partnerId => integer().references(Partners, #id)();
  TextColumn get period => text()(); // e.g., "2026-01"
  RealColumn get amount => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
