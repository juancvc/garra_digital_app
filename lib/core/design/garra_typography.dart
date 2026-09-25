import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'garra_colors.dart';

class GarraTypography {
  GarraTypography._();

  static TextTheme textTheme({
    Color primary = const Color(GarraColors.textPrimary),
    Color secondary = const Color(GarraColors.textSecondary),
    Brightness brightness = Brightness.dark,
  }) {
    final base = GoogleFonts.montserratTextTheme(
      (brightness == Brightness.dark
              ? ThemeData.dark(useMaterial3: true)
              : ThemeData.light(useMaterial3: true))
          .textTheme,
    );

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: secondary,
      ),
    );
  }

  static TextStyle numeric({
    double size = 28,
    FontWeight weight = FontWeight.w900,
    Color? color,
  }) {
    return GoogleFonts.montserrat(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.1,
    );
  }
}
