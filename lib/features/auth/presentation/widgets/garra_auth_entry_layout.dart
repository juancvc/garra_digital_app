import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_puma_crest.dart';
import 'garra_auth_video_backdrop.dart';

/// Stadium hero + readable form zone for Welcome, Login and Register.
class GarraAuthEntryLayout extends StatefulWidget {
  const GarraAuthEntryLayout({
    super.key,
    this.onBack,
    required this.body,
    this.showCrest = true,
    this.heroTitle,
    this.heroSubtitle,
  });

  final VoidCallback? onBack;
  final Widget body;
  final bool showCrest;
  final String? heroTitle;
  final String? heroSubtitle;

  static const stadiumAsset = 'assets/images/auth/garra_stadium_night.webp';

  @override
  State<GarraAuthEntryLayout> createState() => _GarraAuthEntryLayoutState();
}

class _GarraAuthEntryLayoutState extends State<GarraAuthEntryLayout>
    with SingleTickerProviderStateMixin {
  AnimationController? _ambient;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _ambient?.dispose();
      _ambient = null;
      return;
    }
    if (_ambient != null) return;
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ambient = _ambient;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0C0B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(GarraAuthEntryLayout.stadiumAsset),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          const GarraAuthVideoBackdrop(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xCC0E0C0B),
                  const Color(0xD947101C),
                  const Color(0xF20E0C0B),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
          if (ambient != null)
            AnimatedBuilder(
              animation: ambient,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(ambient.value);
                return RepaintBoundary(
                  key: const ValueKey('auth-ambient-aura'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.18 + t * 0.36, -0.5),
                        radius: 1.05,
                        colors: [
                          const Color(
                            GarraColors.gold,
                          ).withValues(alpha: 0.04 + t * 0.06),
                          const Color(
                            GarraColors.burgundy,
                          ).withValues(alpha: 0.025 + t * 0.02),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      key: const ValueKey('auth-flow-back'),
                      tooltip: 'Volver',
                      onPressed: widget.onBack,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFFF7F0E2),
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          GarraSpacing.lg,
                          GarraSpacing.sm,
                          GarraSpacing.lg,
                          GarraSpacing.xxl,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 8,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (widget.showCrest) ...[
                                    const Center(
                                      child: GarraPumaCrest(size: 76),
                                    ),
                                    const SizedBox(height: GarraSpacing.md),
                                  ],
                                  if (widget.heroTitle != null) ...[
                                    Text(
                                      widget.heroTitle!,
                                      textAlign: TextAlign.center,
                                      style: text.headlineSmall?.copyWith(
                                        color: const Color(0xFFF7F0E2),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    if (widget.heroSubtitle != null) ...[
                                      const SizedBox(height: GarraSpacing.sm),
                                      Text(
                                        widget.heroSubtitle!,
                                        textAlign: TextAlign.center,
                                        style: text.bodyMedium?.copyWith(
                                          color: const Color(0xFFE8DED0),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: GarraSpacing.xl),
                                  ],
                                  widget.body,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card surface for login fields over the stadium hero.
class GarraAuthFormCard extends StatelessWidget {
  const GarraAuthFormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(GarraColors.gold).withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: child,
      ),
    );
  }
}
