import 'package:flutter/material.dart';

import '../design/garra_radius.dart';
import '../theme/garra_semantic_colors.dart';
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
        color: context.garraColors.surfaceMuted,
        borderRadius: BorderRadius.circular(GarraRadius.sm),
      ),
    );
  }
}

class GarraHomeSkeleton extends StatelessWidget {
  const GarraHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: const [
        GarraSkeleton(height: 88),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 180),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 120),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 100),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 140),
      ],
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

class GarraConversationSkeleton extends StatelessWidget {
  const GarraConversationSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(GarraSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        Align(alignment: Alignment.centerLeft,
            child: GarraSkeleton(height: 54, width: 220)),
        SizedBox(height: GarraSpacing.md),
        Align(alignment: Alignment.centerRight,
            child: GarraSkeleton(height: 72, width: 240)),
        SizedBox(height: GarraSpacing.md),
        Align(alignment: Alignment.centerLeft,
            child: GarraSkeleton(height: 48, width: 180)),
      ],
    ),
  );
}

class GarraEmptyState extends StatelessWidget {
  /// DEMO HARDENING 01: reusable first-use / empty pattern.
  /// Optional [hint] is a short "¿Cómo funciona?" line; never a blocking tutorial.
  const GarraEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.hint,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 32,
                  color: context.garraColors.brandPrestige),
              const SizedBox(height: GarraSpacing.md),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: GarraSpacing.sm),
              Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              if (hint != null && hint!.trim().isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.sm),
                Text(hint!, key: const ValueKey('empty_hint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.garraColors.textSecondary),
                    textAlign: TextAlign.center),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: GarraSpacing.xl),
                GarraSecondaryButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GarraErrorState extends StatelessWidget {
  const GarraErrorState({
    super.key,
    this.title = 'No pudimos cargar la información',
    this.message = 'Revisa tu conexión e inténtalo de nuevo.',
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: context.garraColors.brandPrestige, size: 40),
              const SizedBox(height: GarraSpacing.lg),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: GarraSpacing.sm),
              Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: GarraSpacing.xl),
              GarraPrimaryButton(label: 'Reintentar', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
