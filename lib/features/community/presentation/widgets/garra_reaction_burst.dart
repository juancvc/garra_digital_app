import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/garra_semantic_colors.dart';
import '../../data/reaction_type.dart';
import 'garra_comment_reactions.dart';

/// Remembers where the last reaction control was tapped (global rect), so the
/// GARRA burst can land on the reacted area without threading keys through
/// every card. Only a Rect is kept (no BuildContext retention).
abstract final class GarraReactionAnchor {
  static Rect? _lastRect;

  static Rect? get lastRect => _lastRect;

  static void remember(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      _lastRect = box.localToGlobal(Offset.zero) & box.size;
    }
  }

  @visibleForTesting
  static void reset() => _lastRect = null;
}

/// Duration of the GARRA micro-animation.
const garraBurstDuration = Duration(milliseconds: 700);

/// Plays the GARRA micro-animation over everything (root overlay, ignores
/// pointers, never blocks). Call ONLY when the user explicitly selects GARRA.
/// Skipped when the platform asks to reduce motion.
void showGarraReactionBurst(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  if (media?.disableAnimations ?? false) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final size = media?.size ?? const Size(360, 640);
  final rect = GarraReactionAnchor.lastRect;
  final target = rect == null
      ? Offset(size.width / 2, size.height / 2)
      : Offset(
          rect.width > 120 ? rect.left + 24 : rect.center.dx,
          rect.center.dy,
        );

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _GarraBurst(
      target: target,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _GarraBurst extends StatefulWidget {
  const _GarraBurst({required this.target, required this.onDone});

  final Offset target;
  final VoidCallback onDone;

  @override
  State<_GarraBurst> createState() => _GarraBurstState();
}

class _GarraBurstState extends State<_GarraBurst>
    with SingleTickerProviderStateMixin {
  static const double _glyph = 56;
  static const double _rise = 72;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: garraBurstDuration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenCompleteOrCancel(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final tint = commentReactionTint(context, ReactionType.garra);
    return IgnorePointer(
      key: const ValueKey('garra_reaction_burst'),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // 0-0.4 appear enlarged, 0.4-0.6 impact pulse, 0.6-1 land.
          double scale;
          double opacity;
          double rise;
          if (t < 0.4) {
            final p = Curves.easeOutBack.transform(t / 0.4);
            scale = 0.4 + 0.8 * p;
            opacity = (t / 0.15).clamp(0.0, 1.0);
            rise = _rise;
          } else if (t < 0.6) {
            final p = (t - 0.4) / 0.2;
            scale = 1.2 + 0.1 * math.sin(p * math.pi);
            opacity = 1;
            rise = _rise;
          } else {
            final p = Curves.easeInCubic.transform((t - 0.6) / 0.4);
            scale = 1.2 - 0.9 * p;
            opacity = 1 - ((p - 0.6) / 0.4).clamp(0.0, 1.0);
            rise = _rise * (1 - p);
          }
          final ringT = ((t - 0.4) / 0.3).clamp(0.0, 1.0);
          final center = widget.target - Offset(0, rise);
          const box = _glyph * 2.2;
          return Stack(
            children: [
              Positioned(
                left: center.dx - box / 2,
                top: center.dy - box / 2,
                width: box,
                height: box,
                child: Opacity(
                  opacity: opacity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (ringT > 0 && ringT < 1)
                        Container(
                          width: _glyph * (1 + ringT),
                          height: _glyph * (1 + ringT),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tint.withValues(alpha: 0.5 * (1 - ringT)),
                              width: 3,
                            ),
                          ),
                        ),
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: _glyph,
                          height: _glyph,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surface,
                            border: Border.all(color: tint, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: tint.withValues(alpha: 0.35),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: GarraClawReactionGlyph(
                            size: _glyph * 0.62,
                            color: tint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}