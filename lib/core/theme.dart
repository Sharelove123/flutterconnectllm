import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryDark = Color(0xFF0D0D1A);
  static const surfaceDark = Color(0xFF12122A);
  static const accentPurple = Color(0xFF6C5CE7);
  static const accentCyan = Color(0xFF00CEFF);
  static const successGreen = Color(0xFF00D68F);
  static const errorRed = Color(0xFFFF6B6B);
  static const textPrimary = Colors.white;
  static const textMuted = Color(0xFF8F8FA3);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentPurple,
        brightness: Brightness.dark,
        primary: accentPurple,
        secondary: accentCyan,
        surface: surfaceDark,
        error: errorRed,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          height: 1.6,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          height: 1.5,
          color: textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          height: 1.4,
          color: textMuted,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: primaryDark,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accentPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
      ),
    );
  }
}
