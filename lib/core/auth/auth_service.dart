import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../di/providers.dart';

/// SHA-256 hex hash used for storing user passwords.
String hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();

/// All routable modules, used by sidebar filtering, router guard and the
/// permissions editor in users management.
const List<String> appModules = [
  'dashboard',
  'pos',
  'sales-history',
  'customers',
  'products',
  'categories',
  'returns',
  'purchases',
  'purchase-history',
  'inventory',
  'inventory-count',
  'expiration-alerts',
  'suppliers',
  'fawry',
  'treasury',
  'expenses',
  'shifts',
  'partners',
  'reports',
  'settings',
  'users',
  'audit',
];

/// Arabic display names for modules (permissions editor, audit view).
const Map<String, String> moduleLabels = {
  'dashboard': 'لوحة التحكم',
  'pos': 'نقطة البيع',
  'sales-history': 'فواتير المبيعات',
  'customers': 'العملاء',
  'products': 'المنتجات',
  'categories': 'التصنيفات',
  'returns': 'المرتجعات',
  'purchases': 'المشتريات',
  'purchase-history': 'فواتير المشتريات',
  'inventory': 'المخزن',
  'inventory-count': 'جرد المخزون',
  'expiration-alerts': 'تنبيهات الصلاحية',
  'suppliers': 'الموردون',
  'fawry': 'إدارة فوري',
  'treasury': 'الخزنة',
  'expenses': 'المصروفات',
  'shifts': 'الشيفتات',
  'partners': 'الشركاء',
  'reports': 'التقارير',
  'settings': 'الإعدادات',
  'users': 'المستخدمين',
  'audit': 'سجل العمليات',
};

/// Default permissions per role, applied when creating a user or when the
/// role changes. Keeps non-admin roles scoped to their own job.
const Map<String, Map<String, List<String>>> roleDefaults = {
  'cashier': {
    'dashboard': ['view'],
    'pos': ['view', 'create'],
    'sales-history': ['view'],
    'customers': ['view', 'create'],
    'returns': ['view', 'create'],
    'shifts': ['view'],
    'products': ['view'],
    'suppliers': ['view'],
    'purchases': ['view', 'create'],
    'purchase-history': ['view'],
    'expenses': ['view', 'create'],
    'fawry': ['view', 'create'],
    'treasury': ['view'],
  },
  'accountant': {
    'dashboard': ['view'],
    'pos': ['view'],
    'sales-history': ['view'],
    'customers': ['view', 'create', 'edit'],
    'suppliers': ['view', 'create', 'edit'],
    'treasury': ['view', 'create'],
    'expenses': ['view', 'create'],
    'shifts': ['view', 'create'],
    'reports': ['view'],
    'partners': ['view'],
  },
  'storekeeper': {
    'dashboard': ['view'],
    'products': ['view', 'create', 'edit'],
    'categories': ['view', 'create', 'edit'],
    'purchases': ['view', 'create'],
    'purchase-history': ['view'],
    'inventory': ['view'],
    'inventory-count': ['view', 'create'],
    'expiration-alerts': ['view'],
    'suppliers': ['view', 'create'],
    'returns': ['view', 'create'],
  },
};

/// Effective permission map for a role (module -> allowed ops).
/// Admins get everything on every module.
Map<String, List<String>> defaultPermissionsForRole(String role) {
  if (role == 'admin') {
    return {
      for (final m in appModules) m: const ['view', 'create', 'edit', 'delete'],
    };
  }
  return roleDefaults[role] ?? {};
}

class AuthService {
  AuthService._();

  static const sessionKey = 'session_user_id';

  /// Verify credentials against the users table.
  /// Accepts a sha256 hash or a legacy plaintext value.
  static Future<User?> authenticate(
    AppDatabase db,
    String username,
    String password,
  ) async {
    final user = await (db.select(db.users)
          ..where((t) => t.username.equals(username.trim())))
        .getSingleOrNull();
    if (user == null || !user.isActive) return null;
    if (user.passwordHash == hashPassword(password) ||
        user.passwordHash == password) {
      return user;
    }
    return null;
  }

  /// Restore a persisted session before the app renders.
  static Future<void> restoreSession(ProviderContainer container) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt(sessionKey);
    if (uid == null) return;
    final db = container.read(databaseProvider);
    final user = await (db.select(db.users)
          ..where((t) => t.id.equals(uid)))
        .getSingleOrNull();
    if (user != null && user.isActive) {
      container.read(currentUserIdProvider.notifier).state = user.id;
      container.read(currentUserProvider.notifier).state = user;
    } else {
      await prefs.remove(sessionKey);
    }
  }

  static Future<void> persistSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(sessionKey, userId);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionKey);
  }

  /// Synchronous permission check. Admins bypass all checks.
  static bool hasPermission(
    User? user,
    List<Permission> perms,
    String module,
    String op,
  ) {
    if (user == null) return false;
    if (user.role == 'admin') return true;
    Permission? p;
    for (final e in perms) {
      if (e.module == module) {
        p = e;
        break;
      }
    }
    if (p == null) return false;
    switch (op) {
      case 'create':
        return p.canCreate;
      case 'edit':
        return p.canEdit;
      case 'delete':
        return p.canDelete;
      default:
        return p.canView;
    }
  }
}

/// Convenience wrapper reading the session providers.
bool can(WidgetRef ref, String module, [String op = 'view']) {
  final user = ref.read(currentUserProvider);
  final perms = ref.read(permissionsProvider).value ?? [];
  return AuthService.hasPermission(user, perms, module, op);
}
