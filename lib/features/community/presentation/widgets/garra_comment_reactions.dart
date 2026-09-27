import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_sheet.dart';
import '../../data/reaction_type.dart';

/// Comment reactions exposed by the mobile V1 UI. The backend accepts more
/// types, but comments only offer these three.
const commentReactionTypes = <ReactionType>[
  ReactionType.love,
  ReactionType.fire,
  ReactionType.garra,
];

bool isCommentReactionType(String? apiValue) {
  final type = ReactionType.tryParse(apiValue);
  return type != null && commentReactionTypes.contains(type);
}

/// Short Spanish label (also the accessibility label) for comment reactions.
String commentReactionLabel(ReactionType type) {
  return switch (type) {
    ReactionType.love => 'Me encanta',
    ReactionType.fire => 'Fuego',
    ReactionType.garra => 'Garra',
    _ => type.labelEs,
  };
}

/// Theme-aware tint per reaction. GARRA uses the brand accent of each theme:
/// garnet on Crema, gold on Noche Monumental.
Color commentReactionTint(BuildContext context, ReactionType type) {
  final colors = context.garraColors;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (type) {
    ReactionType.love => colors.danger,
    ReactionType.fire => colors.warning,
    _ => isDark ? colors.brandPrestige : colors.brandPrimary,
  };
}

/// Accent used for the "selected" state of the comment react control.
Color commentReactionAccent(BuildContext context) {
  final colors = context.garraColors;
  return Theme.of(context).brightness == Brightness.dark
      ? colors.brandPrestige
      : colors.brandPrimary;
}

/// Vector icon for a comment reaction: heart, flame or the Garra claw glyph.
class CommentReactionIcon extends StatelessWidget {
  const CommentReactionIcon({
    super.key,
    required this.type,
    this.size = 18,
    this.color,
  });

  final ReactionType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? commentReactionTint(context, type);
    return switch (type) {
      ReactionType.love => Icon(
        Icons.favorite_rounded,
        size: size,
        color: tint,
      ),
      ReactionType.fire => Icon(
        Icons.local_fire_department_rounded,
        size: size,
        color: tint,
      ),
      _ => GarraClawReactionGlyph(size: size, color: tint),
    };
  }
}

/// Branded claw glyph for the GARRA reaction: three tapered, curved claw
/// slashes (a puma scratch). Drawn as vector paths, tintable per theme and
/// legible at 16-24 logical px. Not an emoji and not a paw print.
class GarraClawReactionGlyph extends StatelessWidget {
  const GarraClawReactionGlyph({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: GarraClawReactionPainter(color: color),
    );
  }
}

class GarraClawReactionPainter extends CustomPainter {
  GarraClawReactionPainter({required this.color});

  final Color color;

  static const double _viewBox = 24;

  /// Top and bottom points of each slash inside a 24-unit box. The middle
  /// claw is the longest, like a real scratch.
  static const List<(Offset, Offset)> _slashes = [
    (Offset(9.6, 3.6), Offset(3.8, 19.6)),
    (Offset(14.8, 1.8), Offset(8.8, 21.8)),
    (Offset(20.2, 4.4), Offset(14.6, 20.0)),
  ];

  static const double _halfWidth = 1.75;
  static const double _bend = 2.2;

  /// Lens-shaped slash: pointed tips, thickest in the middle, slightly
  /// curved like a claw.
  static Path slashPath(Offset top, Offset bottom) {
    final delta = bottom - top;
    final length = delta.distance;
    final dir = delta / length;
    final normal = Offset(-dir.dy, dir.dx);
    final mid = (top + bottom) / 2;
    final outer = mid + normal * (_bend + _halfWidth * 2);
    final inner = mid + normal * (_bend - _halfWidth * 2);
    return Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(outer.dx, outer.dy, bottom.dx, bottom.dy)
      ..quadraticBezierTo(inner.dx, inner.dy, top.dx, top.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    canvas.save();
    canvas.translate(
      (size.width - _viewBox * scale) / 2,
      (size.height - _viewBox * scale) / 2,
    );
    canvas.scale(scale);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = color;
    for (final (top, bottom) in _slashes) {
      canvas.drawPath(slashPath(top, bottom), fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GarraClawReactionPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Compact summary: up to three reaction icons plus the total count.
/// Renders nothing when there are no reactions (no noisy "0 reacciones").
class GarraCommentReactionSummary extends StatelessWidget {
  const GarraCommentReactionSummary({
    super.key,
    required this.reactionSummary,
    required this.reactionCount,
  });

  final Map<String, int> reactionSummary;
  final int reactionCount;

  @override
  Widget build(BuildContext context) {
    if (reactionCount <= 0) return const SizedBox.shrink();
    final colors = context.garraColors;
    final visible =
        commentReactionTypes
            .where((type) => (reactionSummary[type.apiValue] ?? 0) > 0)
            .toList()
          ..sort(
            (a, b) => (reactionSummary[b.apiValue] ?? 0).compareTo(
              reactionSummary[a.apiValue] ?? 0,
            ),
          );
    final label = reactionCount == 1
        ? '1 reacción'
        : '$reactionCount reacciones';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (visible.isEmpty)
            Icon(
              Icons.favorite_border_rounded,
              size: 14,
              color: colors.textSecondary,
            )
          else
            for (final type in visible)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: CommentReactionIcon(type: type, size: 16),
              ),
          const SizedBox(width: 4),
          Text(
            '$reactionCount',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact bottom sheet with only LOVE, FIRE and GARRA.
Future<ReactionType?> showCommentReactionPicker(
  BuildContext context, {
  String? currentReaction,
}) {
  return showGarraSheet<ReactionType>(
    context: context,
    builder: (_) =>
        GarraCommentReactionPicker(currentReaction: currentReaction),
  );
}

class GarraCommentReactionPicker extends StatelessWidget {
  const GarraCommentReactionPicker({super.key, this.currentReaction});

  final String? currentReaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final selected = ReactionType.tryParse(currentReaction);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.lg,
        ),
        child: Column(
          key: const ValueKey('comment_reaction_picker'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reacciona al comentario',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: GarraSpacing.xs),
              Text(
                'Toca tu reacción otra vez para quitarla',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: GarraSpacing.md),
            Row(
              children: [
                for (final type in commentReactionTypes)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _PickerOption(
                        type: type,
                        selected: selected == type,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  const _PickerOption({required this.type, required this.selected});

  final ReactionType type;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final tint = commentReactionTint(context, type);
    final label = commentReactionLabel(type);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: selected ? tint.withValues(alpha: 0.16) : colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          side: BorderSide(
            color: selected ? tint : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('comment_reaction_option_${type.apiValue}'),
          borderRadius: BorderRadius.circular(GarraRadius.md),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop(type);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: GarraSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommentReactionIcon(type: type, size: 28),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
