import 'package:flutter/material.dart';

import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';

/// Sign-in with Google using the standard multicolor G asset (brand guidelines).
class GarraGoogleSignInButton extends StatelessWidget {
  const GarraGoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool primary;

  static const _googleGAsset = 'assets/images/auth/google_signin_g.png';

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                _googleGAsset,
                width: 20,
                height: 20,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(width: GarraSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: primary ? colors.onBrand : colors.textPrimary,
                  ),
                ),
              ),
            ],
          );

    if (primary) {
      return FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GarraRadius.md),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.border),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
        ),
      ),
      child: child,
    );
  }
}
