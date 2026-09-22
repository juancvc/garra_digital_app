import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_radius.dart';
import '../design/garra_spacing.dart';

class GarraCard extends StatelessWidget {
  const GarraCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(GarraRadius.xl);
    final body = Padding(
      padding: padding ?? const EdgeInsets.all(GarraSpacing.lg),
      child: child,
    );

    // Material surface is required so nested ListTiles can paint ink/splash
    // (Flutter asserts when ListTile sits under a colored DecoratedBox only).
    return Material(
      color: const Color(GarraColors.surface),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: const Color(GarraColors.borderSubtle)),
          ),
          child: body,
        ),
      ),
    );
  }
}
