import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_radius.dart';
import '../design/garra_typography.dart';

/// V3 theme — burgundy CTAs, gold only for prestige accents.
class AppTheme {
  AppTheme._();

  static const Color background = Color(GarraColors.background);
  static const Color cream = Color(GarraColors.cream);
  static const Color gold = Color(GarraColors.gold);
  static const Color burgundy = Color(GarraColors.burgundy);

  static ThemeData get darkTheme {
    final textTheme = GarraTypography.textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: burgundy,
        secondary: gold,
        tertiary: cream,
        surface: Color(GarraColors.surface),
        onPrimary: cream,
        onSecondary: background,
        onSurface: Color(GarraColors.textPrimary),
        error: Color(GarraColors.danger),
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: Color(GarraColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(GarraColors.surface),
        indicatorColor: burgundy.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? cream : const Color(GarraColors.textSecondary),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? cream : const Color(GarraColors.textSecondary),
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: burgundy,
          foregroundColor: cream,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GarraRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cream,
          side: BorderSide(color: cream.withValues(alpha: 0.25)),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GarraRadius.md),
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
        prefixIconColor: const Color(GarraColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          borderSide: BorderSide(color: cream.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          borderSide: const BorderSide(color: burgundy, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(GarraColors.surfaceRaised),
        contentTextStyle: const TextStyle(color: Color(GarraColors.textPrimary)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cream.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(GarraColors.surfaceRaised),
        textStyle: const TextStyle(color: Color(GarraColors.textPrimary)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
        ),
      ),
    );
  }
}
