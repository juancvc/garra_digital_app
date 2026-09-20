import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_radius.dart';
import '../design/garra_typography.dart';

/// V2 theme built on Garra semantic tokens. Preserves Montserrat + stadium night.
class AppTheme {
  AppTheme._();

  // Backward-compatible aliases used across existing screens.
  static const Color background = Color(GarraColors.charcoal);
  static const Color cream = Color(GarraColors.cream);
  static const Color gold = Color(GarraColors.gold);
  static const Color burgundy = Color(GarraColors.garnet);

  static ThemeData get darkTheme {
    final textTheme = GarraTypography.textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: cream,
        secondary: gold,
        tertiary: burgundy,
        surface: Color(GarraColors.surface),
        onPrimary: burgundy,
        onSecondary: background,
        onSurface: cream,
      ),
      textTheme: textTheme,
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
            borderRadius: BorderRadius.circular(GarraRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(GarraColors.surfaceRaised),
        hintStyle: TextStyle(
          color: cream.withValues(alpha: 0.45),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: cream.withValues(alpha: 0.75),
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: gold,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          borderSide: BorderSide(
            color: cream.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          borderSide: const BorderSide(
            color: gold,
            width: 1.4,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(GarraColors.surface),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.xl),
          side: BorderSide(
            color: cream.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}
