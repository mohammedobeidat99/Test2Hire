import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors - Modern Tech Indigo & Cyan
  static const Color primary = Color(0xFF4F46E5); // Vibrant Indigo
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color accent = Color(0xFF06B6D4); // Electric Cyan
  static const Color violet = Color(0xFF8B5CF6);

  // Brand Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Secondary & Dark Neutrals
  static const Color secondary = Color(0xFF0F172A); // Slate Dark
  static const Color secondaryLight = Color(0xFF334155);

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Rose/Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // Neutrals - Light Theme
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Input styling colors
  static const Color inputFill = Color(0xFFF8FAFC);
  static const Color inputBorder = Color(0xFFE2E8F0);

  // Subtle semantic tints
  static const Color primarySubtle = Color(0xFFEEF2FF);
  static const Color successSubtle = Color(0xFFECFDF5);
  static const Color warningSubtle = Color(0xFFFFFBEB);
  static const Color errorSubtle = Color(0xFFFEF2F2);
  static const Color infoSubtle = Color(0xFFF0F9FF);

  // Box Shadows
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x120F172A),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x404F46E5),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  // Neutrals - Dark Theme
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
}
