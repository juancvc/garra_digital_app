import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_claw_mark.dart';

/// CHAT_V2_A: conversation background. Theme background plus a sparse,
/// nearly imperceptible pattern of the original Garra claw strokes (shared
/// [GarraClawGeometry]); vector only, no raster asset, no logo tiling.
class ChatBackdrop extends StatelessWidget {
  const ChatBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: colors.background,
      child: CustomPaint(
        key: const Key('chat-backdrop'),
        painter: ChatBackdropPainter(
          color: colors.textPrimary.withValues(alpha: dark ? 0.03 : 0.045),
        ),
        child: child,
      ),
    );
  }
}

class ChatBackdropPainter extends CustomPainter {
  ChatBackdropPainter({required this.color});

  final Color color;

  static const double _cell = 148;
  static const double _mark = 40;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final claws = GarraClawGeometry.claws();
    final scale = _mark / GarraClawGeometry.viewBox;
    var row = 0;
    for (var y = 24.0; y < size.height; y += _cell, row++) {
      final offset = row.isOdd ? _cell / 2 : 0.0;
      var col = 0;
      for (var x = 20.0 + offset; x < size.width; x += _cell, col++) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(((row + col) % 3 - 1) * math.pi / 14);
        canvas.scale(scale);
        for (final path in claws) {
          canvas.drawPath(path, paint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(ChatBackdropPainter oldDelegate) =>
      oldDelegate.color != color;
}
