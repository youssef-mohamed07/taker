import 'package:drift/drift.dart';
import 'user_tables.dart';

/// Tracks the Fawry Machine's digital balance and the total cash collected
class FawryMachine extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  /// The virtual digital balance on the Fawry machine (رصيد الماكينة الافتراضي)
  RealColumn get digitalBalance => real().withDefault(const Constant(0))();
  
  /// The physical cash collected from customers that belongs to Fawry
  /// This sits in the main safe but needs to be tracked separately.
  RealColumn get cashCollected => real().withDefault(const Constant(0))();
  
  /// Total profits accumulated from Fawry transactions
  RealColumn get totalProfits => real().withDefault(const Constant(0))();
  
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Fawry Transactions Log
class FawryTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  /// 'service' (دفع فاتورة/شحن), 'recharge' (تزويد رصيد من المندوب)
  TextColumn get type => text()(); 
  
  /// The amount deducted from or added to the digital balance
  RealColumn get amount => real()();
  
  /// For 'service' type: How much the customer actually paid in cash
  RealColumn get customerPaid => real().nullable()();
  
  /// The profit from this specific transaction
  RealColumn get profit => real().withDefault(const Constant(0))();
  
  TextColumn get description => text().nullable()();
  
  IntColumn get userId => integer().references(Users, #id).nullable()();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
