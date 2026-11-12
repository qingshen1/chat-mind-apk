import 'package:flutter/material.dart';

class AppTheme {
  // ==================== 基础色板 ====================
  static const Color bgDark = Color(0xFF0A0E21);
  static const Color bgDarker = Color(0xFF060919);
  static const Color bgCard = Color(0xFF151A30);
  static const Color bgCardLight = Color(0xFF1E2440);
  static const Color bgCardGlass = Color(0xCC151A30);

  // ==================== 强调色渐变 ====================
  static const Color accentStart = Color(0xFF6C63FF);
  static const Color accentEnd = Color(0xFF3F9BF5);
  static const Color accentPurple = Color(0xFF9D50BB);
  static const Color accentPink = Color(0xFFE73C7E);
  static const Color accentCyan = Color(0xFF00D2FF);

  // ==================== 功能色 ====================
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFA0A4B8);
  static const Color textMuted = Color(0xFF6B7080);
  static const Color danger = Color(0xFFFF5757);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFD43B);

  // ==================== 渐变定义 ====================

  /// 主强调渐变（紫蓝）
  static LinearGradient get accentGradient => const LinearGradient(
        colors: [accentStart, accentEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// 紫粉渐变
  static LinearGradient get purplePinkGradient => const LinearGradient(
        colors: [accentPurple, accentPink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// 青蓝渐变
  static LinearGradient get cyanBlueGradient => const LinearGradient(
        colors: [accentCyan, accentEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// 背景渐变（深色）
  static LinearGradient get bgGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bgDark, bgDarker],
      );

  /// 卡片玻璃态渐变
  static LinearGradient get cardGlassGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          bgCardLight.withOpacity(0.15),
          bgCard.withOpacity(0.08),
        ],
      );

  /// 危险渐变
  static LinearGradient get dangerGradient => const LinearGradient(
        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// 成功渐变
  static LinearGradient get successGradient => const LinearGradient(
        colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ==================== 阴影/光效 ====================

  static List<BoxShadow> get accentGlow => [
        BoxShadow(
          color: accentStart.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ==================== 边框/装饰 ====================

  static BorderSide get glassBorder => BorderSide(
        color: Colors.white.withOpacity(0.08),
        width: 1,
      );

  // ==================== 主题数据 ====================

  static ThemeData get darkTheme => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgDark,
        colorScheme: const ColorScheme.dark(
          primary: accentStart,
          secondary: accentEnd,
          surface: bgCard,
          onSurface: textPrimary,
        ),
        cardTheme: CardThemeData(
          color: bgCard.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
          bodySmall: TextStyle(fontSize: 12, color: textMuted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgDarker,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentStart, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: textMuted),
          hintStyle: TextStyle(color: textMuted.withOpacity(0.5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentStart,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withOpacity(0.06),
          thickness: 1,
          space: 1,
        ),
      );
}
