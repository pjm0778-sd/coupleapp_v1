import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2C2C2C);
  static const Color accent = Color(0xFFE8A598);
  static const Color background = Color(0xFFF9F9F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEEEEEE);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF9E9E9E);

  // Schedule color presets (20 distinct colors)
  static const List<Color> scheduleColors = [
    // Red/Pink (데이트용)
    Color(0xFFFF5252), Color(0xFFFF4081), Color(0xFFE91E63),
    // Orange/Yellow
    Color(0xFFFF6D00), Color(0xFFFFCA28), Color(0xFFFFEB3B),
    // Green/Teal
    Color(0xFF00E676), Color(0xFF69F0AE), Color(0xFF00BFA5),
    Color(0xFF4DB6AC),
    // Blue
    Color(0xFF2979FF), Color(0xFF448AFF), Color(0xFF536DFE),
    Color(0xFF64FFDA),
    // Purple
    Color(0xFFE040FB), Color(0xFFD500F9), Color(0xAA00FF),
    // Brown/Gray
    Color(0xFF795548), Color(0xFF8D6E63), Color(0xFF607D8B),
  ];

  // Date schedule border color (데이트용 강조 색상)
  static const Color dateBorderColor = Color(0xFFFF4081);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(primary: primary, surface: surface),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFFBBBBBB),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
