import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../di/providers.dart';
import '../../auth/auth_service.dart';
import '../../database/db_helpers.dart';

/// Main app shell with sidebar navigation
class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final currentPath = GoRouterState.of(context).uri.path;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ScreenTypeLayout.builder(
        mobile: (context) => Scaffold(
          appBar: AppBar(
            title: Text('تاجر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          drawer: Drawer(
            child: Container(
              color: AppColors.sidebarBg,
              child: _buildSidebarContent(context, ref, false, currentPath),
            ),
          ),
          body: child,
        ),
        tablet: (context) => Scaffold(
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isCollapsed ? 72 : 260,
                decoration: BoxDecoration(
                  color: AppColors.sidebarBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(2, 0),
                    ),
                  ],
                ),
                child: _buildSidebarContent(context, ref, isCollapsed, currentPath),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        desktop: (context) => Scaffold(
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isCollapsed ? 72 : 260,
                decoration: BoxDecoration(
                  color: AppColors.sidebarBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(2, 0),
                    ),
                  ],
                ),
                child: _buildSidebarContent(context, ref, isCollapsed, currentPath),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context, WidgetRef ref, bool isCollapsed, String currentPath) {
    final user = ref.watch(currentUserProvider);
    final perms = ref.watch(permissionsProvider).value ?? [];
    bool allowed(String module) =>
        AuthService.hasPermission(user, perms, module, 'view');

    final List<Widget> navChildren = [];
    Widget? pendingSection;

    void section(String title) {
      pendingSection = _buildSectionHeader(context, title, isCollapsed);
    }

    void item(IconData icon, String label, String path,
        {bool isFullScreen = false}) {
      final module = path.replaceFirst('/', '');
      if (!allowed(module)) return;
      
      if (pendingSection != null) {
        navChildren.add(pendingSection!);
        pendingSection = null;
      }

      navChildren.add(_buildNavItem(
        context,
        icon: icon,
        label: label,
        path: path,
        currentPath: currentPath,
        isCollapsed: isCollapsed,
        isFullScreen: isFullScreen,
      ));
    }

    item(LucideIcons.layoutDashboard, 'لوحة التحكم', '/dashboard');
    section('المبيعات');
    item(LucideIcons.monitor, 'نقطة البيع', '/pos', isFullScreen: true);
    item(LucideIcons.fileText, 'فواتير المبيعات', '/sales-history');
    item(LucideIcons.users, 'العملاء', '/customers');
    section('المخزون');
    item(LucideIcons.box, 'المنتجات', '/products');
    item(LucideIcons.tags, 'التصنيفات', '/categories');
    item(LucideIcons.refreshCcw, 'المرتجعات', '/returns');
    item(LucideIcons.shoppingCart, 'المشتريات', '/purchases');
    item(LucideIcons.fileText, 'فواتير المشتريات', '/purchase-history');
    item(LucideIcons.warehouse, 'المخزن', '/inventory');
    item(LucideIcons.clipboardCheck, 'جرد المخزون', '/inventory-count');
    item(LucideIcons.alarmClock, 'تنبيهات الصلاحية', '/expiration-alerts');
    item(LucideIcons.truck, 'الموردون', '/suppliers');
    section('المالية');
    if (can(ref, 'fawry', 'view')) {
      item(LucideIcons.plug, 'إدارة فوري', '/fawry');
    }
    item(LucideIcons.wallet, 'الخزنة', '/treasury');
    item(LucideIcons.receipt, 'المصروفات', '/expenses');
    item(LucideIcons.clock, 'الشيفتات', '/shifts');
    item(LucideIcons.users2, 'الشركاء', '/partners');
    section('النظام');
    item(LucideIcons.barChart3, 'التقارير', '/reports');
    item(LucideIcons.settings, 'الإعدادات', '/settings');
    item(LucideIcons.userCog, 'المستخدمين', '/users');
    item(LucideIcons.fileText, 'سجل العمليات', '/audit');

    return Column(
      children: [
        // Logo / Header
        _buildHeader(context, isCollapsed, ref),

        SizedBox(height: 8.h),

        // Navigation items
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Column(children: navChildren),
          ),
        ),

        // Collapse toggle (only show if not on mobile)
        if (getValueForScreenType<bool>(
          context: context,
          mobile: false,
          tablet: true,
          desktop: true,
        ))
          _buildCollapseButton(context, isCollapsed, ref),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isCollapsed, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.sidebarDivider, width: 1.w),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Text(
                'ت',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!isCollapsed) ...[
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'تاجر',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (user != null)
                    Text(
                      '${user.fullName} (${_roleLabel(user.role)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.sidebarIcon,
                        fontSize: 11.sp,
                        fontFamily: 'Cairo',
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: () => _logout(context, ref),
              icon: Icon(LucideIcons.logOut, color: AppColors.sidebarIcon, size: 20),
            ),
          ],
          if (isCollapsed)
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: () => _logout(context, ref),
              icon: Icon(LucideIcons.logOut, color: AppColors.sidebarIcon, size: 20),
            ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'accountant':
        return 'محاسب';
      case 'cashier':
        return 'كاشير';
      case 'storekeeper':
        return 'أمين مخزن';
      default:
        return role;
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final uid = ref.read(currentUserIdProvider);
    if (uid != null) {
      await DbHelpers.logAudit(
        db,
        userId: uid,
        action: 'LOGOUT',
        targetTable: 'auth',
        details: 'تسجيل خروج',
      );
    }
    await AuthService.clearSession();
    ref.read(currentUserIdProvider.notifier).state = null;
    ref.read(currentUserProvider.notifier).state = null;
    if (context.mounted) context.go('/login');
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isCollapsed) {
    if (isCollapsed) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Divider(color: AppColors.sidebarDivider, height: 1.h),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4, right: 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.sidebarIcon,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String path,
    required String currentPath,
    required bool isCollapsed,
    bool isFullScreen = false,
  }) {
    final isActive = currentPath == path;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isFullScreen) {
              context.push(path);
            } else {
              context.go(path);
            }
          },
          borderRadius: BorderRadius.circular(8.r),
          hoverColor: AppColors.sidebarBgHover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 10.h,
            ),
            decoration: BoxDecoration(
              color: isActive ? AppColors.sidebarBgActive : Colors.transparent,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isActive
                      ? AppColors.sidebarIconActive
                      : AppColors.sidebarIcon,
                ),
                if (!isCollapsed) ...[
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? AppColors.sidebarTextActive
                            : AppColors.sidebarText,
                        fontSize: 16.sp,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(BuildContext context, bool isCollapsed, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.sidebarDivider, width: 1.w),
        ),
      ),
      child: IconButton(
        onPressed: () {
          ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
        },
        icon: Icon(
          isCollapsed ? LucideIcons.chevronsLeft : LucideIcons.chevronsRight,
          color: AppColors.sidebarIcon,
          size: 24,
        ),
        tooltip: isCollapsed ? 'توسيع القائمة' : 'تصغير القائمة',
      ),
    );
  }
}
