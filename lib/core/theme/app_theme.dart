import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_radius.dart';
import '../design/garra_typography.dart';
import 'garra_appearance.dart';
import 'garra_semantic_colors.dart';

/// Garra themes. Noche Monumental keeps the approved stadium-night identity.
/// Crema is the cream-shirt light theme. Screens read [GarraSemanticColors].
class AppTheme {
  AppTheme._();

  static const Color background = Color(GarraColors.background);
  static const Color cream = Color(GarraColors.cream);
  static const Color gold = Color(GarraColors.gold);
  static const Color burgundy = Color(GarraColors.burgundy);

  static ThemeData get darkTheme => _build(GarraSemanticColors.noche);

  static ThemeData get lightTheme => _build(GarraSemanticColors.crema);

  static ThemeData _build(GarraSemanticColors colors) {
    final isDark = colors == GarraSemanticColors.noche ||
        colors.background.computeLuminance() < 0.2;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final textTheme = GarraTypography.textTheme(
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
      brightness: brightness,
    );
    final radius = BorderRadius.circular(GarraRadius.md);
    final overlay = garraOverlayStyle(
      brightness: brightness,
      navigationBar: colors.background,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.brandPrimary,
        onPrimary: colors.onBrand,
        secondary: colors.brandPrestige,
        onSecondary: isDark ? colors.background : colors.textPrimary,
        tertiary: colors.onBrand,
        onTertiary: colors.textPrimary,
        error: colors.danger,
        onError: colors.onBrand,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlay,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.brandPrimary.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.textPrimary : colors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.textPrimary : colors.textSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.lg),
          side: BorderSide(color: colors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceRaised,
        selectedColor: colors.brandPrimary,
        disabledColor: colors.surfaceMuted,
        labelStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: colors.onBrand,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.pill),
        ),
        showCheckmark: true,
        checkmarkColor: colors.onBrand,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brandPrimary,
          foregroundColor: colors.onBrand,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceRaised,
        hintStyle: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        labelStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        helperStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
        errorStyle: TextStyle(color: colors.danger, fontSize: 12),
        prefixIconColor: colors.textSecondary,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.brandPrimary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: TextStyle(color: colors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        textStyle: TextStyle(color: colors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: colors.textSecondary,
        dragHandleSize: const Size(42, 4),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.brandPrestige,
        textColor: colors.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.brandPrestige,
      ),
      iconTheme: IconThemeData(color: colors.textPrimary),
    );
  }
}
