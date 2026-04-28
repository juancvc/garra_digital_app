import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF111111);
  static const Color cream = Color(0xFFFFF1C7);
  static const Color gold = Color(0xFFD6A84F);
  static const Color burgundy = Color(0xFF7A121C);

  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _surfaceAlt = Color(0xFF242424);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.montserratTextTheme(
      ThemeData.dark(useMaterial3: true).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: cream,
        secondary: gold,
        tertiary: burgundy,
        surface: _surface,
        onPrimary: burgundy,
        onSecondary: background,
        onSurface: cream,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: cream,
        displayColor: cream,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: cream,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cream,
          foregroundColor: burgundy,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceAlt,
        hintStyle: TextStyle(
          color: cream.withOpacity(0.45),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: cream.withOpacity(0.75),
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: gold,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: cream.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: gold,
            width: 1.4,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: cream.withOpacity(0.08),
          ),
        ),
      ),
    );
  }
}