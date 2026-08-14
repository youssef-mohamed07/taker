import 'package:flutter/material.dart';

/// Tager Design System - Color Palette
/// Clean, professional, single-theme setup.
class AppColors {
  AppColors._();

  // ─── Primary ─────────────────────────────────────────
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primarySurface = Color(0xFFE3F2FD);

  // ─── Sidebar ─────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF1E293B);
  static const Color sidebarBgHover = Color(0xFF334155);
  static const Color sidebarBgActive = Color(0xFF1565C0);
  static const Color sidebarText = Color(0xFFE2E8F0);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);
  static const Color sidebarIcon = Color(0xFFCBD5E1);
  static const Color sidebarIconActive = Color(0xFFFFFFFF);
  static const Color sidebarDivider = Color(0xFF334155);

  // ─── Background ──────────────────────────────────────
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color cardBg = Color(0xFFFFFFFF);

  // ─── Text ────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textTertiary = Color(0xFF4B5563);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Status ──────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ─── Border ──────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderFocus = Color(0xFF1565C0);

  // ─── Chart Colors ────────────────────────────────────
  static const List<Color> chartColors = [
    Color(0xFF1565C0),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
    Color(0xFFEC4899),
  ];
}
