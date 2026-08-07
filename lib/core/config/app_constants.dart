/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'تاجر';
  static const String appNameEn = 'Tager';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'نظام إدارة تجارة الجملة والمخازن ونقطة البيع';

  static const String dbName = 'tager_db.sqlite';
  static const String backupFolder = 'TagerBackups';

  // Default pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 500;

  // Price types
  static const String priceWholesale = 'wholesale';
  static const String priceSemiWholesale = 'semi_wholesale';
  static const String priceRetail = 'retail';

  // Payment methods
  static const String paymentCash = 'cash';
  static const String paymentCredit = 'credit';
  static const String paymentPartial = 'partial';

  // Movement types
  static const String movementIn = 'IN';
  static const String movementOut = 'OUT';
  static const String movementAdjustment = 'ADJUSTMENT';
  static const String movementDamage = 'DAMAGE';
  static const String movementReturn = 'RETURN';

  // User roles
  static const String roleAdmin = 'admin';
  static const String roleAccountant = 'accountant';
  static const String roleCashier = 'cashier';
  static const String roleStorekeeper = 'storekeeper';

  // Invoice status
  static const String statusDraft = 'draft';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  static const String statusSuspended = 'suspended';
}
