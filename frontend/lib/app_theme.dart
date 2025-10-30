import 'package:flutter/material.dart';

/// Apple-inspired design system for the app
/// Based on iOS Human Interface Guidelines and modern minimalist principles
class AppTheme {
  // ========== COLOR PALETTE ==========

  /// iOS Blue - Primary action color
  static const Color iosBlue = Color(0xFF007AFF);

  /// System colors
  static const Color systemBackground = Color(0xFFF2F2F7); // Soft off-white
  static const Color systemGroupedBackground = Color(0xFFFFFFFF);
  static const Color secondarySystemBackground = Color(0xFFFFFFFF);

  /// Text colors
  static const Color primaryLabel = Color(0xFF000000);
  static const Color secondaryLabel = Color(0xFF3C3C43);
  static const Color tertiaryLabel = Color(0x993C3C43);

  /// UI Element colors
  static const Color separator = Color(0xFFD1D1D6);
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray3 = Color(0xFFC7C7CC);
  static const Color systemGray4 = Color(0xFFD1D1D6);
  static const Color systemGray5 = Color(0xFFE5E5EA);
  static const Color systemGray6 = Color(0xFFF2F2F7);

  /// Semantic colors
  static const Color successGreen = Color(0xFF34C759);
  static const Color warningYellow = Color(0xFFFFCC00);
  static const Color errorRed = Color(0xFFFF3B30);

  // ========== SPACING ==========

  /// 8pt grid spacing system
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // ========== CORNER RADIUS ==========

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 10.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;

  // ========== SHADOWS ==========

  /// Subtle elevated shadow for cards
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Elevated shadow for floating elements
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ========== TYPOGRAPHY ==========

  /// SF Pro-inspired typography scale
  static TextStyle get largeTitle => const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
        height: 1.2,
      );

  static TextStyle get title1 => const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
        height: 1.2,
      );

  static TextStyle get title2 => const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
        height: 1.3,
      );

  static TextStyle get title3 => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        height: 1.3,
      );

  static TextStyle get headline => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        height: 1.35,
      );

  static TextStyle get body => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        height: 1.35,
      );

  static TextStyle get callout => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.32,
        height: 1.35,
      );

  static TextStyle get subheadline => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
        height: 1.35,
      );

  static TextStyle get footnote => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
        height: 1.35,
      );

  static TextStyle get caption1 => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.35,
      );

  static TextStyle get caption2 => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.07,
        height: 1.35,
      );

  // ========== LIGHT THEME ==========

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: iosBlue,
        secondary: systemGray,
        surface: secondarySystemBackground,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: primaryLabel,
        onError: Colors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: systemBackground,

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryLabel,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: primaryLabel,
          letterSpacing: -0.41,
        ),
        iconTheme: IconThemeData(
          color: iosBlue,
          size: 22,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: systemGray4, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: systemGray4, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: iosBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: secondaryLabel,
          letterSpacing: -0.32,
        ),
        hintStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: tertiaryLabel,
          letterSpacing: -0.32,
        ),
        prefixIconColor: systemGray,
        suffixIconColor: systemGray,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing20,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          ),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: iosBlue,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing16,
            vertical: spacing12,
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: iosBlue,
          side: const BorderSide(color: iosBlue, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing20,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          ),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.5,
        space: 1,
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: iosBlue,
        unselectedItemColor: systemGray,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryLabel.withOpacity(0.9),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: primaryLabel,
          letterSpacing: -0.41,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: primaryLabel,
          letterSpacing: -0.08,
        ),
      ),
    );
  }

  // ========== DARK THEME ==========

  static ThemeData get darkTheme {
    const Color darkBackground = Color(0xFF000000);
    const Color darkSurface = Color(0xFF1C1C1E);
    const Color darkSecondaryBackground = Color(0xFF2C2C2E);
    const Color darkPrimaryLabel = Color(0xFFFFFFFF);
    const Color darkSecondaryLabel = Color(0xFFEBEBF5);
    const Color darkTertiaryLabel = Color(0x99EBEBF5);
    const Color darkSeparator = Color(0xFF38383A);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: const ColorScheme.dark(
        primary: iosBlue,
        secondary: systemGray,
        surface: darkSurface,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: darkPrimaryLabel,
        onSurface: darkPrimaryLabel,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: darkBackground,

      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkPrimaryLabel,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkPrimaryLabel,
          letterSpacing: -0.41,
        ),
        iconTheme: IconThemeData(
          color: iosBlue,
          size: 22,
        ),
      ),

      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSecondaryBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: darkSeparator, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: darkSeparator, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: iosBlue, width: 2),
        ),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: darkSecondaryLabel,
        ),
        hintStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: darkTertiaryLabel,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing20,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          ),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: iosBlue,
        unselectedItemColor: systemGray,
        selectedLabelStyle: TextStyle(fontSize: 10),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkPrimaryLabel.withOpacity(0.9),
        contentTextStyle: const TextStyle(
          color: Color(0xFF000000),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkPrimaryLabel,
          letterSpacing: -0.41,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: darkPrimaryLabel,
          letterSpacing: -0.08,
        ),
      ),
    );
  }
}
