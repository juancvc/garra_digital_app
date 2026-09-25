import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/widgets/garra_claw_mark.dart';
import '../data/first_launch_experience_service.dart';
import '../data/intro_audio.dart';

class GarraPrimordialIntroPage extends StatefulWidget {
  const GarraPrimordialIntroPage({
    super.key,
    this.intro,
    this.hasSession,
    this.audio,
  });

  final FirstLaunchExperienceService? intro;
  final Future<bool> Function()? hasSession;
  final IntroAudio? audio;

  @override
  State<GarraPrimordialIntroPage> createState() =>
      _GarraPrimordialIntroPageState();
}

class _GarraPrimordialIntroPageState extends State<GarraPrimordialIntroPage>
    with SingleTickerProviderStateMixin {
  static const _fullDuration = Duration(milliseconds: 6200);
  static const _reducedDuration = Duration(milliseconds: 800);

  late final FirstLaunchExperienceService _intro =
      widget.intro ?? FirstLaunchExperienceService();
  late final IntroAudio _audio = widget.audio ?? AssetIntroAudio();
  late final AnimationController _controller;
  var _reduced = false;
  var _left = false;
  var _started = false;
  var _audioClosed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _controller =
        AnimationController(
          vsync: this,
          duration: _reduced ? _reducedDuration : _fullDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            unawaited(_leave());
          }
        });
    _controller.forward();
    unawaited(_startAudio());
  }

  Future<void> _startAudio() async {
    try {
      await _audio.start();
    } catch (_) {}
  }

  Future<bool> _session() {
    final lookup = widget.hasSession;
    if (lookup != null) return lookup();
    return SecureStorageService().hasToken();
  }

  Future<void> _leave() async {
    if (_left) return;
    _left = true;
    _controller.stop();
    await _closeAudio();
    try {
      await _intro.markIntroSeen();
    } catch (_) {}
    if (!mounted) return;
    final authed = await _session();
    if (!mounted) return;
    context.go(authed ? '/home' : '/login');
  }

  Future<void> _closeAudio() async {
    if (_audioClosed) return;
    _audioClosed = true;
    try {
      await _audio.stop();
    } catch (_) {}
    _audio.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_closeAudio());
    super.dispose();
  }

  double _span(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    final raw = (t - start) / (end - start);
    return Curves.easeInOut.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.background),
      body: Semantics(
        explicitChildNodes: true,
        label: 'Garra Digital. De hinchas para hinchas.',
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final showSkip = _reduced || t >= (800 / 6200);
            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.15),
                      radius: 1.05,
                      colors: [
                        Color(GarraColors.burgundyDeep),
                        Color(GarraColors.background),
                      ],
                    ),
                  ),
                ),
                if (!_reduced)
                  ExcludeSemantics(
                    child: CustomPaint(painter: _HazePainter(t)),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 20),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 40,
                            child: showSkip
                                ? TextButton(
                                    onPressed: () => unawaited(_leave()),
                                    child: const Text(
                                      'Omitir',
                                      style: TextStyle(
                                        color: Color(GarraColors.creamMuted),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _Stage(t: t, reduced: _reduced, span: _span),
                          ),
                        ),
                        Opacity(
                          opacity: _reduced ? t : _span(t, 0.84, 0.96),
                          child: const Text(
                            'Comunidad no oficial de hinchas cremas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(GarraColors.creamMuted),
                              fontSize: 12,
                              letterSpacing: 0.3,
                              height: 1.3,
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
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.t, required this.reduced, required this.span});

  final double t;
  final bool reduced;
  final double Function(double t, double start, double end) span;

  @override
  Widget build(BuildContext context) {
    final title = reduced ? t : span(t, 0.56, 0.72);
    final claim = reduced ? t : span(t, 0.66, 0.82);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 168,
          height: 168,
          child: CustomPaint(
            painter: _IntroMarkPainter(t: t, reduced: reduced),
          ),
        ),
        const SizedBox(height: 28),
        Opacity(
          opacity: title,
          child: Transform.translate(
            offset: Offset(0, (1 - title) * 10),
            child: Text(
              'GARRA DIGITAL',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(GarraColors.cream),
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: claim,
          child: Transform.translate(
            offset: Offset(0, (1 - claim) * 8),
            child: Text(
              'De hinchas para hinchas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(GarraColors.cream),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroMarkPainter extends CustomPainter {
  _IntroMarkPainter({required this.t, required this.reduced});

  final double t;
  final bool reduced;

  double _span(double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / GarraClawGeometry.viewBox;
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

    if (reduced) {
      canvas.save();
      canvas.scale(scale);
      canvas.drawPath(GarraClawGeometry.spine(), cream);
      canvas.drawPath(GarraClawGeometry.middleClaw(), cream);
      canvas.drawPath(GarraClawGeometry.lowerClaw(), cream);
      canvas.drawPath(GarraClawGeometry.goldTip(), gold);
      canvas.restore();
      return;
    }

    final revealEnds = [0.22, 0.26, 0.30];
    final claws = GarraClawGeometry.claws();
    final settle = _span(0.28, 0.44);
    final glow = _span(0.44, 0.56);
    final pulse = glow <= 0
        ? 0.0
        : 0.45 + 0.25 * math.sin((t - 0.44) * math.pi * 4);
    if (glow > 0) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.42,
        Paint()
          ..color = const Color(
            GarraColors.burgundy,
          ).withValues(alpha: 0.35 * pulse.clamp(0, 1)),
      );
    }

    final eye = _span(0.34, 0.40) * (1 - _span(0.42, 0.50));
    if (eye > 0) {
      final eyePaint = Paint()
        ..color = const Color(GarraColors.gold).withValues(alpha: 0.28 * eye);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * 0.42, size.height * 0.46),
            width: 16,
            height: 3,
          ),
          const Radius.circular(2),
        ),
        eyePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * 0.58, size.height * 0.46),
            width: 16,
            height: 3,
          ),
          const Radius.circular(2),
        ),
        eyePaint,
      );
    }

    canvas.save();
    canvas.scale(scale);
    for (var i = 0; i < claws.length; i++) {
      final reveal = _span(0.11 + i * 0.03, revealEnds[i]);
      final scatter = 1 - settle;
      canvas.save();
      canvas.translate((i - 1) * 16 * scatter, (i == 1 ? -10 : 8) * scatter);
      for (final metric in claws[i].computeMetrics()) {
        final portion = metric.extractPath(0, metric.length * reveal);
        canvas.drawPath(portion, cream);
      }
      canvas.restore();
    }
    if (settle > 0.85) {
      canvas.drawPath(GarraClawGeometry.goldTip(), gold);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IntroMarkPainter oldDelegate) => oldDelegate.t != t;
}

class _HazePainter extends CustomPainter {
  _HazePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(GarraColors.cream);
    for (var i = 0; i < 14; i++) {
      final x = size.width * (0.08 + ((i * 37) % 84) / 100);
      final y = size.height * (0.12 + ((i * 19) % 70) / 100);
      final drift = math.sin(t * math.pi * 2 + i) * 4;
      final alpha = 0.04 + (i % 3) * 0.015;
      paint.color = const Color(
        GarraColors.cream,
      ).withValues(alpha: alpha * t.clamp(0.2, 1));
      canvas.drawCircle(Offset(x, y + drift), 1.4 + (i % 3) * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_HazePainter oldDelegate) => oldDelegate.t != t;
}
