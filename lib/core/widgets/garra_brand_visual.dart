import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_radius.dart';
import '../design/garra_spacing.dart';

/// Unofficial supporters-community crest used across Garra Digital.
///
/// It deliberately uses a simple "U" monogram rather than an official club
/// asset. The surrounding copy must keep the non-official positioning clear.
class GarraCrest extends StatelessWidget {
  const GarraCrest({super.key, this.size = 44, this.showGlow = false});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(GarraColors.cream),
        border: Border.all(
          color: const Color(GarraColors.gold),
          width: size * 0.035,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(
                    GarraColors.burgundy,
                  ).withValues(alpha: 0.6),
                  blurRadius: size * 0.45,
                  spreadRadius: size * 0.04,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        'U',
        style: TextStyle(
          color: const Color(GarraColors.burgundyDeep),
          fontSize: size * 0.48,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

class GarraBrandLockup extends StatelessWidget {
  const GarraBrandLockup({
    super.key,
    this.compact = false,
    this.crestSize = 42,
  });

  final bool compact;
  final double crestSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GarraCrest(size: crestSize),
        const SizedBox(width: GarraSpacing.sm),
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GARRA DIGITAL',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(GarraColors.cream),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              if (!compact)
                Text(
                  'COMUNIDAD NO OFICIAL DE HINCHAS CREMAS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(GarraColors.gold),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.65,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Image-forward editorial hero shared by match, discovery and profile.
class GarraAtmosphericHero extends StatelessWidget {
  const GarraAtmosphericHero({
    super.key,
    required this.child,
    this.height = 220,
    this.assetPath = 'assets/visual/garra_match_hero.png',
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.all(GarraSpacing.lg),
    this.borderRadius = GarraRadius.lg,
  });

  final Widget child;
  final double height;
  final String assetPath;
  final Alignment alignment;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: alignment,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(GarraColors.burgundyDeep)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x240E0C0B),
                    Color(0xB8170D10),
                    Color(0xF00E0C0B),
                  ],
                  stops: [0, 0.56, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.75, -0.7),
                  radius: 1.25,
                  colors: [
                    const Color(GarraColors.burgundy).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class GarraEditorialEyebrow extends StatelessWidget {
  const GarraEditorialEyebrow({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(GarraColors.burgundy).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(GarraRadius.pill),
        border: Border.all(
          color: const Color(GarraColors.gold).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: const Color(GarraColors.cream)),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(GarraColors.cream),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// A subtle stadium-light backdrop that adds atmosphere without another card.
class GarraSectionAtmosphere extends StatelessWidget {
  const GarraSectionAtmosphere({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GarraSpacing.lg),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GarraRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(GarraColors.burgundyDeep), Color(GarraColors.surface)],
        ),
        border: Border.all(color: const Color(GarraColors.borderSubtle)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -44,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(GarraColors.gold).withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: const Color(GarraColors.gold).withValues(alpha: 0.1),
                    blurRadius: 48,
                    spreadRadius: 16,
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
