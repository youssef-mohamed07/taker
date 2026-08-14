import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../di/providers.dart';

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
    return Column(
      children: [
        // Logo / Header
        _buildHeader(context, isCollapsed, ref),

        SizedBox(height: 8.h),

        // Navigation items
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Column(
              children: [
                _buildNavItem(
                  context,
                  icon: LucideIcons.layoutDashboard,
                  label: 'لوحة التحكم',
                  path: '/dashboard',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildSectionHeader(context, 'المبيعات', isCollapsed),
                _buildNavItem(
                  context,
                  icon: LucideIcons.monitor,
                  label: 'نقطة البيع',
                  path: '/pos',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                  isFullScreen: true,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.fileText,
                  label: 'فواتير المبيعات',
                  path: '/sales-history',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.users,
                  label: 'العملاء',
                  path: '/customers',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildSectionHeader(context, 'المخزون', isCollapsed),
                _buildNavItem(
                  context,
                  icon: LucideIcons.box,
                  label: 'المنتجات',
                  path: '/products',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.tags,
                  label: 'التصنيفات',
                  path: '/categories',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.refreshCcw,
                  label: 'المرتجعات',
                  path: '/returns',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.shoppingCart,
                  label: 'المشتريات',
                  path: '/purchases',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.fileText,
                  label: 'فواتير المشتريات',
                  path: '/purchase-history',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.warehouse,
                  label: 'المخزن',
                  path: '/inventory',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.clipboardCheck,
                  label: 'جرد المخزون',
                  path: '/inventory-count',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.truck,
                  label: 'الموردون',
                  path: '/suppliers',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildSectionHeader(context, 'المالية', isCollapsed),
                _buildNavItem(
                  context,
                  icon: LucideIcons.wallet,
                  label: 'الخزنة',
                  path: '/treasury',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.receipt,
                  label: 'المصروفات',
                  path: '/expenses',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.clock,
                  label: 'الشيفتات',
                  path: '/shifts',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.users2,
                  label: 'الشركاء',
                  path: '/partners',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildSectionHeader(context, 'النظام', isCollapsed),
                _buildNavItem(
                  context,
                  icon: LucideIcons.barChart3,
                  label: 'التقارير',
                  path: '/reports',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.settings,
                  label: 'الإعدادات',
                  path: '/settings',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.userCog,
                  label: 'المستخدمين',
                  path: '/users',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.fileText,
                  label: 'سجل العمليات',
                  path: '/audit',
                  currentPath: currentPath,
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
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
            Text(
              'تاجر',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ],
      ),
    );
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
