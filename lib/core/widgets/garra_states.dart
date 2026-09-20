import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_radius.dart';
import '../design/garra_spacing.dart';
import 'garra_ui.dart';

class GarraSkeleton extends StatelessWidget {
  const GarraSkeleton({super.key, this.height = 16, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(GarraColors.surfaceRaised),
        borderRadius: BorderRadius.circular(GarraRadius.sm),
      ),
    );
  }
}

class GarraPassportSkeleton extends StatelessWidget {
  const GarraPassportSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: const [
        SizedBox(height: GarraSpacing.xl),
        Center(child: GarraSkeleton(height: 88, width: 88)),
        SizedBox(height: GarraSpacing.lg),
        Center(child: GarraSkeleton(height: 24, width: 180)),
        SizedBox(height: GarraSpacing.sm),
        Center(child: GarraSkeleton(height: 16, width: 120)),
        SizedBox(height: GarraSpacing.xxl),
        GarraSkeleton(height: 120),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 100),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 140),
      ],
    );
  }
}

class GarraEmptyState extends StatelessWidget {
  const GarraEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GarraSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: GarraSpacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: GarraSpacing.xl),
              GarraSecondaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class GarraErrorState extends StatelessWidget {
  const GarraErrorState({
    super.key,
    this.title = 'No pudimos cargar tu Pasaporte',
    this.message = 'Revisa tu conexión e inténtalo de nuevo.',
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GarraSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Color(GarraColors.gold), size: 40),
            const SizedBox(height: GarraSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: GarraSpacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: GarraSpacing.xl),
            GarraPrimaryButton(label: 'Reintentar', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
