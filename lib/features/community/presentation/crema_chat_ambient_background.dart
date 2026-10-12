import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_puma_crest.dart';

/// Light animated crema/gold ambient layer for Comunidad Crema chat.
class CremaChatAmbientBackground extends StatefulWidget {
  const CremaChatAmbientBackground({
    super.key,
    required this.child,
    this.active = true,
  });

  final Widget child;
  final bool active;

  @override
  State<CremaChatAmbientBackground> createState() => _CremaChatAmbientBackgroundState();
}

class _CremaChatAmbientBackgroundState extends State<CremaChatAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_Particle> _particles;

  static const _crestAsset = GarraIntroAssets.puma;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 52))
      ..repeat();
    _particles = _seedParticles(14);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context);
    final run = widget.active && !reduceMotion;
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller.stop();
    }

    // PRODUCT-07C: dark keeps the original night base; light uses a cream gradient from tokens.
    final light = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (light)
          DecoratedBox(
            key: const ValueKey('crema_ambient_base_light'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(GarraColors.cream),
                  context.garraColors.background,
                ],
              ),
            ),
          )
        else
          const ColoredBox(
            key: ValueKey('crema_ambient_base_dark'),
            color: Color(0xFF120C0E),
          ),
        _BigCremaCrestBackdrop(light: light),
        if (run)
          RepaintBoundary(
            key: const ValueKey('crema_ambient_motion'),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _SparkPainter(progress: _controller.value, light: light),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // PRODUCT-07D: the crest PNG is opaque (RGB, dark backdrop), so in light mode each
                    // floating crest rendered as a small dark square. Light keeps only the round sparks.
                    if (!light)
                      for (var i = 0; i < _particles.length; i++)
                      _FloatingCrest(
                        particle: _particles[i],
                        progress: _controller.value,
                        asset: _crestAsset,
                      ),
                  ],
                ),
              ),
            ),
          )
        else
          const KeyedSubtree(
            key: ValueKey('crema_ambient_static'),
            child: SizedBox.expand(),
          ),
        widget.child,
      ],
    );
  }

  List<_Particle> _seedParticles(int count) {
    final random = math.Random(42);
    return List.generate(count, (i) {
      return _Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: 14 + random.nextDouble() * 16,
        speed: 0.035 + random.nextDouble() * 0.07,
        drift: random.nextDouble() * math.pi * 2,
        opacity: 0.12 + random.nextDouble() * 0.18,
      );
    });
  }
}

class _BigCremaCrestBackdrop extends StatelessWidget {
  const _BigCremaCrestBackdrop({required this.light});

  final bool light;

  /// PRODUCT-07D: `garra_puma.png` has no alpha channel (RGB, near-black + red smoke backdrop). Drawn at low
  /// opacity over the cream gradient its whole rectangle showed as a grey-beige box with hard edges. Light
  /// mode turns luminance into alpha (dark backdrop → transparent), tints it with the Garra burgundy and fades
  /// the edges with a radial mask, so no rectangle can show. The asset itself is untouched.
  static const lightTint = Color(GarraColors.burgundy);
  static const lightOpacity = 0.07;
  static final ColorFilter lightLumaToAlpha = ColorFilter.matrix(<double>[
    0, 0, 0, 0, (lightTint.r * 255).roundToDouble(),
    0, 0, 0, 0, (lightTint.g * 255).roundToDouble(),
    0, 0, 0, 0, (lightTint.b * 255).roundToDouble(),
    0.2126, 0.7152, 0.0722, 0, -40,
  ]);

  @override
  Widget build(BuildContext context) {
    if (light) {
      return IgnorePointer(
        child: Align(
          alignment: const Alignment(0.55, -0.35),
          child: Opacity(
            key: const ValueKey('crema_ambient_crest_light'),
            opacity: lightOpacity,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const RadialGradient(
                center: Alignment(0, -0.12),
                radius: 0.62,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.55, 1],
              ).createShader(rect),
              child: ColorFiltered(
                colorFilter: lightLumaToAlpha,
                child: Image.asset(
                  GarraIntroAssets.puma,
                  width: 240,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0.55, -0.35),
        child: Opacity(
          opacity: 0.11,
          child: Image.asset(
            GarraIntroAssets.puma,
            width: 260,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _FloatingCrest extends StatelessWidget {
  const _FloatingCrest({
    required this.particle,
    required this.progress,
    required this.asset,
  });

  final _Particle particle;
  final double progress;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final y = (particle.y + progress * particle.speed) % 1.15 - 0.08;
    final x = particle.x + math.sin(progress * math.pi * 2 + particle.drift) * 0.025;
    return Positioned(
      left: x * size.width,
      top: y * size.height,
      child: Opacity(
        opacity: particle.opacity,
        child: Image.asset(
          asset,
          width: particle.size,
          height: particle.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.opacity,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double drift;
  final double opacity;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.progress, this.light = false});

  final double progress;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final seed = i * 1.7 + progress * math.pi * 2;
      final dx = (random.nextDouble() * 0.85 + 0.05) * size.width;
      final dy = ((random.nextDouble() + progress * 0.08) % 1.0) * size.height;
      final paint = Paint()..color = Color.lerp(
            light ? const Color(0x26C7A45B) : const Color(0x22C7A45B),
            light ? const Color(0x18781C30) : const Color(0x44F3E9D2),
            (math.sin(seed) + 1) * 0.5,
          )!;
      if (light) {
        // PRODUCT-07D: soft round dots in light mode (blurred edge, never square).
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      }
      canvas.drawCircle(Offset(dx, dy), 1.2 + (i.isEven ? 0.8 : 0.2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.light != light;
}
