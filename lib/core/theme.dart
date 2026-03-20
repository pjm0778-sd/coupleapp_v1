import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Core Colors ──────────────────────────────────────────
  static const Color primary         = Color(0xFFB5547C); // 스위트 로즈
  static const Color accent          = Color(0xFFC9A84C); // 소프트 골드 (유지)
  static const Color accentLight     = Color(0xFFFDE8F0); // 핑크 연배경
  static const Color coral           = Color(0xFFF48FB1); // 소프트 핑크
  static const Color background      = Color(0xFFFFF3F6); // 블러시 화이트
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color border          = Color(0xFFF5D5E2); // 로즈 보더

  // ── Text Colors ───────────────────────────────────────────
  static const Color textPrimary     = Color(0xFF2C1A22); // 따뜻한 다크
  static const Color textSecondary   = Color(0xFF7B5060); // 웜 뮤트 로즈
  static const Color textTertiary    = Color(0xFFBF9AAA); // 연한 로즈

  // ── Semantic Colors ───────────────────────────────────────
  static const Color success         = Color(0xFF38A169);
  static const Color error           = Color(0xFFE53E3E);
  static const Color warning         = Color(0xFFD97706);

  // ── Calendar ─────────────────────────────────────────────
  static const Color dateBorderColor = Color(0xFFB5547C); // = primary rose

  // ── Shadows ───────────────────────────────────────────────
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x1AB5547C), // rose-tinted 10%
    blurRadius: 24,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );
  static const BoxShadow subtleShadow = BoxShadow(
    color: Color(0x12B5547C), // rose-tinted 7%
    blurRadius: 12,
    spreadRadius: 0,
    offset: Offset(0, 2),
  );
  static const BoxShadow navShadow = BoxShadow(
    color: Color(0x14B5547C), // rose-tinted nav
    blurRadius: 20,
    offset: Offset(0, -4),
  );

  // ── Schedule Color Presets (20색 유지, 채도 소폭 조정) ───
  static const List<Color> scheduleColors = [
    Color(0xFFE05252),
    Color(0xFFE0407A),
    Color(0xFFD81B60),
    Color(0xFFEF6C00),
    Color(0xFFFFB300),
    Color(0xFFFFD600),
    Color(0xFF00C853),
    Color(0xFF57D98A),
    Color(0xFF00ACC1),
    Color(0xFF4DB6AC),
    Color(0xFF1E88E5),
    Color(0xFF3D8EF0),
    Color(0xFF4D5EDE),
    Color(0xFF26C6DA),
    Color(0xFFCE50D6),
    Color(0xFFAB47BC),
    Color(0xFF7B52E0),
    Color(0xFF6D4C41),
    Color(0xFF8D6E63),
    Color(0xFF546E7A),
  ];

  static ThemeData get light {
    final baseTextTheme = GoogleFonts.notoSansKrTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,

      // ── Typography ──────────────────────────────────────
      textTheme: baseTextTheme.copyWith(
        displayLarge:  baseTextTheme.displayLarge?.copyWith(color: textPrimary),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: textPrimary),
        displaySmall:  baseTextTheme.displaySmall?.copyWith(color: textPrimary),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w700,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w700,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w600,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w600,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: textPrimary),
        bodyLarge:  baseTextTheme.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textPrimary),
        bodySmall:  baseTextTheme.bodySmall?.copyWith(color: textSecondary),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w600,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(color: textSecondary),
        labelSmall:  baseTextTheme.labelSmall?.copyWith(color: textTertiary),
      ),

      // ── AppBar ──────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),

      // ── BottomNavigationBar ──────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.notoSansKr(
          fontSize: 11, fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.notoSansKr(fontSize: 11),
      ),

      // ── Card ────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Divider ─────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),

      // ── ElevatedButton ───────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── OutlinedButton ───────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 14, fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── TextButton ───────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input ────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.notoSansKr(color: textTertiary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),

      // ── TabBar ───────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textTertiary,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: border,
        labelStyle: GoogleFonts.notoSansKr(
          fontSize: 13, fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.notoSansKr(fontSize: 13),
      ),

      // ── FloatingActionButton ─────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // ── Checkbox ─────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Switch ───────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return border;
        }),
      ),

      // ── Dialog ───────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: GoogleFonts.notoSansKr(
          color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.notoSansKr(
          color: textSecondary, fontSize: 14, height: 1.5,
        ),
      ),

      // ── NavigationBar (Material 3) ───────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: accentLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.notoSansKr(
              fontSize: 11, fontWeight: FontWeight.w600, color: primary,
            );
          }
          return GoogleFonts.notoSansKr(fontSize: 11, color: textTertiary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: textTertiary, size: 22);
        }),
      ),

      // ── ProgressIndicator ────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
      ),
    );
  }
}
