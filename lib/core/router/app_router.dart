import '../../features/inventory/presentation/views/inventory_count_view.dart';
import '../../features/users/presentation/views/users_view.dart';
import '../../features/finance/presentation/views/expenses_view.dart';
import '../../features/sales_history/presentation/views/sales_history_view.dart';
import '../../features/purchases/presentation/views/purchase_history_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/dashboard/presentation/views/dashboard_view.dart';
import '../../features/products/presentation/views/products_view.dart';
import '../../features/products/presentation/views/product_form_view.dart';
import '../../features/products/presentation/views/categories_view.dart';
import '../../features/pos/presentation/views/pos_view.dart';
import '../../features/purchases/presentation/views/purchases_view.dart';
import '../../features/inventory/presentation/views/inventory_view.dart';
import '../../features/customers/presentation/views/customers_view.dart';
import '../../features/suppliers/presentation/views/suppliers_view.dart';
import '../../features/treasury/presentation/views/treasury_view.dart';
import '../../features/shifts/presentation/views/shifts_view.dart';
import '../../features/partners/presentation/views/partners_view.dart';
import '../../features/reports/presentation/views/reports_view.dart';
import '../../features/settings/presentation/views/settings_view.dart';
import '../../features/audit/presentation/views/audit_view.dart';
import '../../features/returns/presentation/views/returns_view.dart';

import '../common/widgets/app_shell.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      // Login (no shell)
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),

      // POS (full screen, no shell)
      GoRoute(path: '/pos', builder: (context, state) => PosView(initialData: state.extra as Map<String, dynamic>?)),

      // Main app with sidebar shell
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', redirect: (_, __) => '/dashboard'),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardView()),
          ),
          GoRoute(
            path: '/products',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProductsView()),
          ),
          GoRoute(
            path: '/products/add',
            builder: (context, state) => const ProductFormView(),
          ),
          GoRoute(
            path: '/products/edit/:id',
            builder: (context, state) => ProductFormView(
              productId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/categories',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CategoriesView()),
          ),
          GoRoute(
            path: '/purchases',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PurchasesView()),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InventoryView()),
          ),
          GoRoute(
            path: '/customers',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CustomersView()),
          ),
          GoRoute(
            path: '/suppliers',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SuppliersView()),
          ),
          GoRoute(
            path: '/treasury',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TreasuryView()),
          ),
          GoRoute(
            path: '/shifts',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ShiftsView()),
          ),
          GoRoute(
            path: '/partners',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PartnersView()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsView()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsView()),
          ),
          GoRoute(
            path: '/audit',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AuditView()),
          ),

          GoRoute(
            path: '/returns',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReturnsView()),
          ),
          GoRoute(
            path: '/expenses',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ExpensesView()),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UsersView()),
          ),
          GoRoute(
            path: '/inventory-count',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InventoryCountView()),
          ),

          GoRoute(
            path: '/sales-history',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SalesHistoryView()),
          ),
          GoRoute(
            path: '/purchase-history',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PurchaseHistoryView()),
          ),
        ],
      ),
    ],
  );
}
