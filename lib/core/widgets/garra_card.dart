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
    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(GarraSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(GarraColors.surface),
        borderRadius: BorderRadius.circular(GarraRadius.xl),
        border: Border.all(color: const Color(GarraColors.borderSubtle)),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GarraRadius.xl),
        child: content,
      ),
    );
  }
}
