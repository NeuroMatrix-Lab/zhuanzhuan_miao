import 'package:flutter/material.dart';

/// 糖果色主题 token + Material3 ThemeData
class AppColors {
  AppColors._();

  static const background = Color(0xFFF5F7FA);
  static const card = Color(0xFFFFFFFF);
  static const selection = Color(0xFFD6E4FF);
  static const sidebar = Color(0xFFF0F2F5);
  static const outlineLight = Color(0xFFD5DAE2);

  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFFA0A8B4);
  static const textComment = Color(0xFF8E99A4);

  static const accentBlue = Color(0xFF5B8DEF);
  static const accentPurple = Color(0xFFA66CFF);
  static const accentMint = Color(0xFF38D9A9);
  static const focusBorder = Color(0xFF5B8DEF);
  static const success = Color(0xFF38D9A9);
  static const warning = Color(0xFFFFA94D);
  static const error = Color(0xFFFF6B6B);

  static const darkBackground = Color(0xFF1A1E26);
  static const darkCard = Color(0xFF242A34);
  static const darkSidebar = Color(0xFF202630);
  static const darkTextPrimary = Color(0xFFE8EAED);
  static const darkOutline = Color(0xFF3D4654);
  static const darkOutlineVariant = Color(0xFF2F3744);

  static ThemeData light() => _theme(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary: accentBlue,
          onPrimary: Colors.white,
          primaryContainer: selection,
          onPrimaryContainer: textPrimary,
          secondary: accentMint,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFD3F5EA),
          onSecondaryContainer: Color(0xFF0B3D32),
          tertiary: accentPurple,
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFE8DCFF),
          onTertiaryContainer: Color(0xFF2B1055),
          surface: card,
          onSurface: textPrimary,
          surfaceContainerHighest: sidebar,
          onSurfaceVariant: textSecondary,
          outline: textSecondary,
          outlineVariant: outlineLight,
          error: error,
          onError: Colors.white,
        ),
        scaffold: background,
        bar: sidebar,
        barText: textPrimary,
        cardSide: outlineLight,
      );

  static ThemeData dark() => _theme(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          primary: accentBlue,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF2A3F6B),
          onPrimaryContainer: selection,
          secondary: accentMint,
          onSecondary: Color(0xFF00382C),
          secondaryContainer: Color(0xFF1B4D42),
          onSecondaryContainer: Color(0xFFD3F5EA),
          tertiary: accentPurple,
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFF3D2A6B),
          onTertiaryContainer: Color(0xFFE8DCFF),
          surface: darkCard,
          onSurface: darkTextPrimary,
          surfaceContainerHighest: darkSidebar,
          onSurfaceVariant: textSecondary,
          outline: darkOutline,
          outlineVariant: darkOutlineVariant,
          error: error,
          onError: Colors.white,
        ),
        scaffold: darkBackground,
        bar: darkSidebar,
        barText: darkTextPrimary,
        cardSide: darkOutlineVariant,
      );

  static ThemeData _theme({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required Color bar,
    required Color barText,
    required Color cardSide,
  }) {
    final radius = BorderRadius.circular(10);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: bar,
        foregroundColor: barText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: barText,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cardSide),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: cardSide, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.12),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
