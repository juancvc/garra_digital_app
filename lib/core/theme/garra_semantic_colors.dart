import 'package:flutter/material.dart';

/// Theme-aware Garra colors. Screens ask for these instead of guessing
/// whether the current mode is Crema or Noche Monumental.
@immutable
class GarraSemanticColors extends ThemeExtension<GarraSemanticColors> {
  const GarraSemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.brandPrimary,
    required this.brandPrestige,
    required this.onBrand,
    required this.danger,
    required this.success,
    required this.warning,
    required this.mediaBackdrop,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color brandPrimary;
  final Color brandPrestige;
  final Color onBrand;
  final Color danger;
  final Color success;
  final Color warning;

  /// Neutral backing behind photos so Crema does not wash user media.
  final Color mediaBackdrop;

  static const noche = GarraSemanticColors(
    background: Color(0xFF0E0C0B),
    surface: Color(0xFF171311),
    surfaceRaised: Color(0xFF211A17),
    surfaceMuted: Color(0xFF2A221E),
    textPrimary: Color(0xFFF7F0E2),
    textSecondary: Color(0xFFB8AEA0),
    border: Color(0x14F3E9D2),
    brandPrimary: Color(0xFF781C30),
    brandPrestige: Color(0xFFC7A45B),
    onBrand: Color(0xFFF3E9D2),
    danger: Color(0xFFB33A3A),
    success: Color(0xFF3D8B6E),
    warning: Color(0xFFC9A227),
    mediaBackdrop: Color(0xFF171311),
  );

  static const crema = GarraSemanticColors(
    background: Color(0xFFF5EAD5),
    surface: Color(0xFFFFF8EA),
    surfaceRaised: Color(0xFFF0DFC2),
    surfaceMuted: Color(0xFFE7D7BE),
    textPrimary: Color(0xFF261816),
    textSecondary: Color(0xFF6F6257),
    border: Color(0x336F6257),
    brandPrimary: Color(0xFF781C30),
    brandPrestige: Color(0xFFB9944F),
    onBrand: Color(0xFFF5EAD5),
    danger: Color(0xFF8E2A2A),
    success: Color(0xFF2F6B52),
    warning: Color(0xFF8A6A1F),
    mediaBackdrop: Color(0xFF171311),
  );

  @override
  GarraSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? brandPrimary,
    Color? brandPrestige,
    Color? onBrand,
    Color? danger,
    Color? success,
    Color? warning,
    Color? mediaBackdrop,
  }) {
    return GarraSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandPrestige: brandPrestige ?? this.brandPrestige,
      onBrand: onBrand ?? this.onBrand,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      mediaBackdrop: mediaBackdrop ?? this.mediaBackdrop,
    );
  }

  @override
  GarraSemanticColors lerp(ThemeExtension<GarraSemanticColors>? other, double t) {
    if (other is! GarraSemanticColors) return this;
    return GarraSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandPrestige: Color.lerp(brandPrestige, other.brandPrestige, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      mediaBackdrop: Color.lerp(mediaBackdrop, other.mediaBackdrop, t)!,
    );
  }
}

extension GarraSemanticColorsContext on BuildContext {
  GarraSemanticColors get garraColors {
    return Theme.of(this).extension<GarraSemanticColors>() ??
        GarraSemanticColors.noche;
  }
}
