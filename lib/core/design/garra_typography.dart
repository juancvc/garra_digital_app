import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'garra_colors.dart';

class GarraTypography {
  GarraTypography._();

  static TextTheme textTheme() {
    final base = GoogleFonts.montserratTextTheme(
      ThemeData.dark(useMaterial3: true).textTheme,
    );

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: const Color(GarraColors.textPrimary),
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: const Color(GarraColors.textPrimary),
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: const Color(GarraColors.textPrimary),
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(GarraColors.textPrimary),
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: const Color(GarraColors.textPrimary),
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(GarraColors.textSecondary),
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: const Color(GarraColors.textPrimary),
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: const Color(GarraColors.textSecondary),
      ),
    );
  }

  static TextStyle numeric({double size = 28, FontWeight weight = FontWeight.w900}) {
    return GoogleFonts.montserrat(
      fontSize: size,
      fontWeight: weight,
      color: const Color(GarraColors.textPrimary),
      height: 1.1,
    );
  }
}
