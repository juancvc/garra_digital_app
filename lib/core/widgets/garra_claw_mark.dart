import 'package:flutter/material.dart';

import '../design/garra_colors.dart';

/// Shared claw-G geometry. The Android launcher vector uses the same
/// 108-unit coordinates.
abstract final class GarraClawGeometry {
  static const double viewBox = 108;

  static Path spine() {
    return Path()
      ..moveTo(74, 32)
      ..cubicTo(60, 20, 34, 22, 28, 40)
      ..cubicTo(22, 58, 30, 78, 50, 84)
      ..cubicTo(62, 88, 72, 80, 74, 70);
  }

  static Path middleClaw() {
    return Path()
      ..moveTo(42, 52)
      ..cubicTo(56, 46, 68, 48, 82, 42);
  }

  static Path lowerClaw() {
    return Path()
      ..moveTo(36, 62)
      ..cubicTo(44, 78, 64, 82, 80, 68);
  }

  static Path goldTip() {
    return Path()
      ..moveTo(70, 46)
      ..lineTo(82, 42);
  }

  static List<Path> claws() => [spine(), middleClaw(), lowerClaw()];
}

/// Original Garra mark: three claw strokes that read as an abstract G.
class GarraClawMark extends StatelessWidget {
  const GarraClawMark({
    super.key,
    required this.size,
    this.showPlate = false,
    this.progress = 1,
  });

  final double size;
  final bool showPlate;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: GarraClawMarkPainter(showPlate: showPlate, progress: progress),
      ),
    );
  }
}

class GarraClawMarkPainter extends CustomPainter {
  GarraClawMarkPainter({required this.showPlate, required this.progress});

  final bool showPlate;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / GarraClawGeometry.viewBox;
    if (showPlate) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.width * 0.22),
        ),
        Paint()..color = const Color(GarraColors.burgundyDeep),
      );
    }
    canvas.save();
    canvas.scale(scale);
    final cream = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(GarraColors.cream);
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(GarraColors.gold);
    final claws = GarraClawGeometry.claws();
    for (final path in claws) {
      _drawPartial(canvas, path, progress.clamp(0, 1), cream);
    }
    if (progress >= 0.98) {
      canvas.drawPath(GarraClawGeometry.goldTip(), gold);
    }
    canvas.restore();
  }

  void _drawPartial(Canvas canvas, Path path, double t, Paint paint) {
    if (t <= 0) return;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(GarraClawMarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.showPlate != showPlate;
  }
}
