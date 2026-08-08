import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/di/providers.dart';

class TagerApp extends ConsumerWidget {
  const TagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(1920, 1080), // Desktop/Tablet typical size as base, we can adjust later
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'تاجر - نظام إدارة تجارة الجملة',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: AppRouter.router,
          locale: const Locale('ar'),
          builder: (context, widget) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: widget ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
