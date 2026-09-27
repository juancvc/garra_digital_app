import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_sheet.dart';
import '../../data/reaction_type.dart';

/// Full Garra reaction catalog (UX_08A), offered on posts, comments and
/// replies in display order: LIKE, LOVE, FIRE, HAHA, CARE, ANGER, SAD, GARRA.
const commentReactionTypes = ReactionType.values;

bool isCommentReactionType(String? apiValue) {
  final type = ReactionType.tryParse(apiValue);
  return type != null && commentReactionTypes.contains(type);
}

/// Spanish label (also the accessibility label) of a reaction.
String commentReactionLabel(ReactionType type) => type.labelEs;

/// Theme-aware tint per reaction. GARRA uses the brand accent of each theme:
/// garnet on Crema, gold on Noche Monumental.
Color commentReactionTint(BuildContext context, ReactionType type) {
  final colors = context.garraColors;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (type) {
    ReactionType.love || ReactionType.anger => colors.danger,
    ReactionType.fire || ReactionType.haha => colors.warning,
    ReactionType.care => colors.brandPrestige,
    ReactionType.sad => colors.textSecondary,
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

/// Icon for any reaction: vector heart (LOVE), flame (FIRE), hugged heart
/// (CARE) and the Garra Digital mark (GARRA); LIKE, HAHA, ANGER and SAD use
/// their emoji inside a fixed square so every glyph lines up.
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
      ReactionType.care => GarraCareReactionGlyph(
        size: size,
        color: tint,
        heartColor: context.garraColors.danger,
      ),
      ReactionType.garra => GarraClawReactionGlyph(size: size, color: tint),
      _ => SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            type.emoji,
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontSize: size * 0.82, height: 1),
          ),
        ),
      ),
    };
  }
}

/// GARRA reaction glyph: the Garra Digital mark (assets/brand/garra_mark.svg,
/// an abstract "G" formed by three diagonal claw cuts), redrawn as vector
/// paths so it needs no SVG dependency. Tintable per theme and legible at
/// 14-24 logical px. Not an emoji, not a shield, not an official club logo.
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

  /// Geometry of garra_mark.svg (108-unit box). The drawn content spans
  /// roughly x 9..83 / y 11..95 including stroke caps.
  static const double _extent = 88;
  static const Offset _contentCenter = Offset(46, 53);
  static const double _arcStroke = 10;
  static const double _cutStroke = 9;
  static const List<(Offset, Offset)> _cuts = [
    (Offset(52, 34), Offset(74, 56)),
    (Offset(46, 46), Offset(72, 72)),
    (Offset(40, 58), Offset(66, 84)),
  ];

  /// Open "G" arc of the brand mark.
  static Path markArcPath() {
    return Path()
      ..moveTo(78, 28)
      ..cubicTo(70, 20, 58, 16, 46, 18)
      ..cubicTo(28, 21, 14, 36, 14, 54)
      ..cubicTo(14, 72, 28, 87, 46, 90)
      ..cubicTo(58, 92, 70, 88, 78, 80);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _extent;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-_contentCenter.dx, -_contentCenter.dy);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = color;
    canvas.drawPath(markArcPath(), stroke..strokeWidth = _arcStroke);
    stroke.strokeWidth = _cutStroke;
    for (final (from, to) in _cuts) {
      canvas.drawLine(from, to, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GarraClawReactionPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// CARE ("Me importa") glyph: a small heart cradled by two rounded arms drawn
/// with the same round-cap strokes as the Garra mark. Own vector, no emoji and
/// no club logo; clearly different from the LOVE heart and the GARRA mark.
class GarraCareReactionGlyph extends StatelessWidget {
  const GarraCareReactionGlyph({
    super.key,
    required this.size,
    required this.color,
    required this.heartColor,
  });

  final double size;
  final Color color;
  final Color heartColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: GarraCareReactionPainter(armColor: color, heartColor: heartColor),
    );
  }
}

class GarraCareReactionPainter extends CustomPainter {
  GarraCareReactionPainter({required this.armColor, required this.heartColor});

  final Color armColor;
  final Color heartColor;

  /// Heart in a 24-unit box, sitting high so the arms can cradle it.
  static Path heartPath() {
    return Path()
      ..moveTo(12, 15.6)
      ..cubicTo(5.4, 11.6, 5.8, 4.6, 9.6, 4.6)
      ..cubicTo(11, 4.6, 11.8, 5.5, 12, 6.8)
      ..cubicTo(12.2, 5.5, 13, 4.6, 14.4, 4.6)
      ..cubicTo(18.2, 4.6, 18.6, 11.6, 12, 15.6)
      ..close();
  }

  /// Two arms embracing the heart from below (left and right).
  static List<Path> armPaths() {
    return [
      Path()
        ..moveTo(3.4, 8.6)
        ..quadraticBezierTo(2.6, 18.6, 11, 20.6),
      Path()
        ..moveTo(20.6, 8.6)
        ..quadraticBezierTo(21.4, 18.6, 13, 20.6),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.translate(
      (size.width - 24 * scale) / 2,
      (size.height - 24 * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawPath(
      heartPath(),
      Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = heartColor,
    );
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6
      ..isAntiAlias = true
      ..color = armColor;
    for (final path in armPaths()) {
      canvas.drawPath(path, arm);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GarraCareReactionPainter oldDelegate) {
    return oldDelegate.armColor != armColor ||
        oldDelegate.heartColor != heartColor;
  }
}

/// Reaction glyph for any surface (post summary, pickers, reactors list).
class GarraReactionGlyph extends StatelessWidget {
  const GarraReactionGlyph({super.key, required this.apiValue, this.size = 16});

  final String apiValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final type = ReactionType.tryParse(apiValue);
    if (type == null) return SizedBox.square(dimension: size);
    return CommentReactionIcon(type: type, size: size);
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
            for (final type in visible.take(3))
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

/// Compact bottom sheet with the full reaction catalog (4x2 grid).
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
      child: SingleChildScrollView(
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
            GarraReactionGrid(
              selected: selected,
              optionKeyPrefix: 'comment_reaction_option_',
              onSelected: (type) {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(type);
              },
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Compact reaction grid shared by the post and comment pickers: 4 columns
/// (two rows for the 8 reactions); 2 columns when the width left after text
/// scaling is too narrow. Cells are >= 72dp tall and fill the column width,
/// so every target is comfortably above 48dp.
class GarraReactionGrid extends StatelessWidget {
  const GarraReactionGrid({
    super.key,
    required this.selected,
    required this.onSelected,
    this.optionKeyPrefix = 'reaction_option_',
  });

  final ReactionType? selected;
  final ValueChanged<ReactionType> onSelected;
  final String optionKeyPrefix;

  static int columnsFor(double width, double textScale) {
    return width / textScale >= 280 ? 4 : 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = columnsFor(constraints.maxWidth, scale);
        const types = commentReactionTypes;
        final rows = <Widget>[];
        for (var start = 0; start < types.length; start += columns) {
          final slice = types.skip(start).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: i < slice.length
                            ? _ReactionGridCell(
                                type: slice[i],
                                selected: selected == slice[i],
                                optionKey: ValueKey(
                                  '$optionKeyPrefix${slice[i].apiValue}',
                                ),
                                onTap: () => onSelected(slice[i]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        return Column(
          key: ValueKey('reaction_grid_$columns'),
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}

class _ReactionGridCell extends StatelessWidget {
  const _ReactionGridCell({
    required this.type,
    required this.selected,
    required this.optionKey,
    required this.onTap,
  });

  final ReactionType type;
  final bool selected;
  final Key optionKey;
  final VoidCallback onTap;

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
          key: optionKey,
          borderRadius: BorderRadius.circular(GarraRadius.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: GarraSpacing.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: CommentReactionIcon(type: type, size: 28)),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.textPrimary,
                          height: 1.15,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: tint,
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