import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: _colorScheme.surface,
      primaryColor: _colorScheme.primary,

      // AppBar styling
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: _colorScheme.primary,
        elevation: 1,
        shadowColor: Colors.black12,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        iconTheme: IconThemeData(color: _colorScheme.primary),
        centerTitle: false,
      ),

      // TabBar styling ✅ FIXED
      tabBarTheme: TabBarThemeData(
        labelColor: _colorScheme.primary,
        unselectedLabelColor: Colors.black54,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: _colorScheme.primary, width: 3),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        unselectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      ),

      // Cards ✅ FIXED
      cardColor: cardDefault,
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        shadowColor: cardShadow.color,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          backgroundColor: _colorScheme.primary,
          foregroundColor: _colorScheme.onPrimary,
          elevation: 4,
          shadowColor: cardShadow.color,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDefault,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: _colorScheme.primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: _colorScheme.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: _colorScheme.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.black87),
      ),

      // Text styling
      textTheme: _textTheme,

      // Icon theme
      iconTheme: IconThemeData(color: _colorScheme.primary),

      // SnackBar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _colorScheme.primary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider
      dividerColor: Colors.grey.shade300,
    );
  }

  // Core Color Scheme
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0079BF), // Optical Blue
    onPrimary: Colors.white,
    secondary: Color(0xFF4ECDC4), // Aqua Accent
    onSecondary: Colors.white,
    error: Color(0xFFD72638),
    onError: Colors.white,
    background: Color(0xFFF8FAFC),
    onBackground: Colors.black87,
    surface: Colors.white,
    onSurface: Colors.black87,
  );

  // Professional harmonious card colors
  static const Color cardDefault = Colors.white;
  static const Color cardNeutralLight = Color(0xFFF5F7FA);
  static const Color cardPrimaryLight = Color(0xFFD9E9FB);
  static const Color cardSecondaryLight = Color(0xFFCCF0ED);
  static const Color cardInfoLight = Color(0xFFE1F0FF);
  static const Color cardWarningLight = Color(0xFFFFF4E5);
  static const Color cardErrorLight = Color(0xFFFDECEA);

  // Card shadow for subtle elevation
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x220079BF),
    blurRadius: 10,
    offset: Offset(0, 4),
  );

  // Text theme for hierarchy and readability
  static const TextTheme _textTheme = TextTheme(
    headlineLarge: TextStyle(
        fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
    headlineMedium: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
    titleLarge: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
    bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
    bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
    labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
  );
}
