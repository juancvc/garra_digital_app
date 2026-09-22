import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_radius.dart';
import '../design/garra_spacing.dart';
import '../design/garra_typography.dart';

class GarraPrimaryButton extends StatelessWidget {
  const GarraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class GarraSecondaryButton extends StatelessWidget {
  const GarraSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.foregroundColor,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? const Color(GarraColors.cream);
    final border = borderColor ?? const Color(GarraColors.gold);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class GarraStat extends StatelessWidget {
  const GarraStat({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GarraTypography.numeric(size: 22)),
        const SizedBox(height: GarraSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class GarraLevelBadge extends StatelessWidget {
  const GarraLevelBadge({
    super.key,
    required this.levelNumber,
    required this.levelName,
  });

  final int levelNumber;
  final String levelName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GarraSpacing.md,
        vertical: GarraSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(GarraColors.garnetDeep),
        borderRadius: BorderRadius.circular(GarraRadius.pill),
        border: Border.all(color: const Color(GarraColors.gold).withValues(alpha: 0.5)),
      ),
      child: Text(
        'Nivel $levelNumber · $levelName',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(GarraColors.gold),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class GarraProgressBar extends StatelessWidget {
  const GarraProgressBar({
    super.key,
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(GarraRadius.pill),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 10,
        backgroundColor: const Color(GarraColors.surfaceRaised),
        color: const Color(GarraColors.gold),
      ),
    );
  }
}

class GarraSectionHeader extends StatelessWidget {
  const GarraSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: GarraSpacing.xs),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}
