import 'package:flutter/material.dart';
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
      child: Scaffold(
        body: Row(
          children: [
            // ─── Sidebar ───────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isCollapsed ? 72 : 260,
              decoration: const BoxDecoration(
                color: AppColors.sidebarBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Logo / Header
                  _buildHeader(isCollapsed, ref),

                  const SizedBox(height: 8),

                  // Navigation items
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          _buildSectionHeader('المبيعات', isCollapsed),
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
                            icon: LucideIcons.users,
                            label: 'العملاء',
                            path: '/customers',
                            currentPath: currentPath,
                            isCollapsed: isCollapsed,
                          ),
                          _buildSectionHeader('المخزون', isCollapsed),
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
                            icon: LucideIcons.shoppingCart,
                            label: 'المشتريات',
                            path: '/purchases',
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
                            icon: LucideIcons.truck,
                            label: 'الموردون',
                            path: '/suppliers',
                            currentPath: currentPath,
                            isCollapsed: isCollapsed,
                          ),
                          _buildSectionHeader('المالية', isCollapsed),
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
                          _buildSectionHeader('النظام', isCollapsed),
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

                  // Collapse toggle
                  _buildCollapseButton(isCollapsed, ref),
                ],
              ),
            ),

            // ─── Main Content ──────────────────
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCollapsed, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.sidebarDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'ت',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            const Text(
              'تاجر',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isCollapsed) {
    if (isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: AppColors.sidebarDivider, height: 1),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4, right: 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.sidebarIcon,
            fontSize: 11,
            fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(vertical: 2),
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
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.sidebarBgHover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isActive ? AppColors.sidebarBgActive : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? AppColors.sidebarIconActive
                      : AppColors.sidebarIcon,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.sidebarTextActive
                          : AppColors.sidebarText,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      fontFamily: 'Cairo',
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

  Widget _buildCollapseButton(bool isCollapsed, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.sidebarDivider, width: 1),
        ),
      ),
      child: IconButton(
        onPressed: () {
          ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
        },
        icon: Icon(
          isCollapsed ? LucideIcons.chevronsLeft : LucideIcons.chevronsRight,
          color: AppColors.sidebarIcon,
          size: 20,
        ),
        tooltip: isCollapsed ? 'توسيع القائمة' : 'تصغير القائمة',
      ),
    );
  }
}
