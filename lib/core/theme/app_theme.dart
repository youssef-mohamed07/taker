import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Tager App Theme - Material 3 based
/// Tuned for 15" 1024x768 POS Screen with Cairo Typography
class AppTheme {
  AppTheme._();

  static const double borderRadius = 12.0;
  static const double borderRadiusSm = 8.0;
  static const double borderRadiusLg = 16.0;

  static TextTheme _buildTextTheme(Color defaultTextColor, Color secondaryTextColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 26.sp,
        fontWeight: FontWeight.bold,
        color: defaultTextColor,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 22.sp,
        fontWeight: FontWeight.bold,
        color: defaultTextColor,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        color: defaultTextColor,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 17.sp,
        fontWeight: FontWeight.w600,
        color: defaultTextColor,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: secondaryTextColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 16.sp,
        fontWeight: FontWeight.w500,
        color: defaultTextColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 15.sp,
        fontWeight: FontWeight.w400,
        color: defaultTextColor,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 15.sp,
        fontWeight: FontWeight.bold,
        color: defaultTextColor,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
      ),
    );
  }

  // ─── Light Theme ─────────────────────────────────────
  static ThemeData get light {
    final textTheme = _buildTextTheme(AppColors.textPrimary, AppColors.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Cairo',
      textTheme: textTheme,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primarySurface,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.textTertiary,
          fontSize: 14.sp,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.textSecondary,
          fontSize: 15.sp,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSm),
          ),
          textStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSm),
          ),
          textStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
        headingTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 15.sp,
          color: AppColors.textSecondary,
        ),
        dataTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14.sp,
          color: AppColors.textPrimary,
        ),
        dividerThickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLg),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.sidebarBg,
          borderRadius: BorderRadius.circular(6.r),
        ),
        textStyle: TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white,
          fontSize: 13.sp,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusSm),
        ),
      ),
    );
  }

  // ─── Dark Theme ──────────────────────────────────────
  static ThemeData get dark {
    final textTheme = _buildTextTheme(AppColors.textPrimary, AppColors.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Cairo',
      textTheme: textTheme,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryLight,
        primaryContainer: AppColors.primaryDark,
        secondary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusSm),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        hintStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.textSecondary,
          fontSize: 14.sp,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.textSecondary,
          fontSize: 15.sp,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
