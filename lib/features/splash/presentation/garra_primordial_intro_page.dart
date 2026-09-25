import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/widgets/garra_puma_crest.dart';
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
  static const _fullDuration = Duration(milliseconds: 8800);
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
    _precache();
    _controller.forward();
    unawaited(_startAudio());
  }

  void _precache() {
    for (final asset in GarraIntroAssets.all) {
      unawaited(_precacheOne(asset));
    }
  }

  Future<void> _precacheOne(String asset) async {
    try {
      await precacheImage(ResizeImage(AssetImage(asset), width: 720), context);
    } catch (_) {}
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

  double _unit(double t, double startMs, double endMs, Curve curve) {
    final start = startMs / _fullDuration.inMilliseconds;
    final end = endMs / _fullDuration.inMilliseconds;
    if (t <= start) return 0;
    if (t >= end) return 1;
    return curve.transform((t - start) / (end - start));
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
            final showSkip = _reduced || t >= (800 / 8800);
            final exit = _reduced ? 0.0 : _unit(t, 8300, 8800, Curves.easeIn);
            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
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
                          child: Opacity(
                            opacity: (1 - exit).clamp(0, 1),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: _PumaLockup(
                                      t: t,
                                      reduced: _reduced,
                                      width: constraints.maxWidth,
                                      unit: _unit,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: _reduced
                              ? t.clamp(0, 1)
                              : (_unit(t, 6000, 7200, Curves.easeOut) *
                                        (1 - exit))
                                    .clamp(0, 1),
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

class _PumaLockup extends StatelessWidget {
  const _PumaLockup({
    required this.t,
    required this.reduced,
    required this.width,
    required this.unit,
  });

  final double t;
  final bool reduced;
  final double width;
  final double Function(double t, double startMs, double endMs, Curve curve)
  unit;

  @override
  Widget build(BuildContext context) {
    final puma = reduced
        ? _fade(t, 0.02, 0.28)
        : unit(t, 700, 2000, Curves.easeOutCubic);
    final garra = reduced
        ? _fade(t, 0.22, 0.5)
        : unit(t, 2200, 3400, Curves.easeOutCubic);
    final digital = reduced
        ? _fade(t, 0.42, 0.7)
        : unit(t, 3500, 4500, Curves.easeOutCubic);
    final claim = reduced
        ? _fade(t, 0.55, 0.85)
        : unit(t, 5200, 6400, Curves.easeOut);
    final halo = reduced ? claim : unit(t, 4500, 6400, Curves.easeOut);
    final impact = reduced ? 0.0 : _impact(t);
    final pumaScale =
        (ui.lerpDouble(0.86, 1, puma) ?? 1) * (1 + 0.025 * impact);
    final garraSweep = reduced ? 0.0 : unit(t, 3100, 3500, Curves.easeInOut);
    final exitSweep = reduced ? 0.0 : unit(t, 7200, 8300, Curves.easeInOut);
    final pumaSweep = reduced ? 0.0 : unit(t, 900, 2000, Curves.easeInOut);

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        if (halo > 0)
          ExcludeSemantics(
            child: Opacity(
              opacity: (0.5 * halo).clamp(0, 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(GarraColors.burgundy).withValues(alpha: 0.5),
                      const Color(GarraColors.gold).withValues(alpha: 0.14),
                      const Color(GarraColors.background).withValues(alpha: 0),
                    ],
                  ),
                ),
                child: SizedBox(width: width * 0.52, height: width * 0.52),
              ),
            ),
          ),
        if (!reduced && exitSweep > 0 && exitSweep < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SweepPainter(exitSweep)),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (puma > 0)
              Transform.translate(
                offset: Offset(0, (1 - puma) * 10),
                child: Transform.scale(
                  scale: pumaScale,
                  child: Opacity(
                    opacity: puma.clamp(0, 1),
                    child: _Plate(
                      key: const Key('intro-puma'),
                      asset: GarraIntroAssets.puma,
                      width: width * 0.46,
                      alignment: const Alignment(0, -0.08),
                      heightFactor: 0.46,
                      sweep: pumaSweep,
                    ),
                  ),
                ),
              ),
            if (garra > 0)
              Transform.translate(
                offset: Offset(0, (1 - garra) * 36 - 8),
                child: Transform.scale(
                  scale: ui.lerpDouble(0.96, 1, garra) ?? 1,
                  child: Opacity(
                    opacity: garra.clamp(0, 1),
                    child: _Plate(
                      key: const Key('intro-garra'),
                      asset: GarraIntroAssets.garra,
                      width: width * 0.56,
                      alignment: const Alignment(0, 0.62),
                      heightFactor: 0.15,
                      sweep: garraSweep,
                    ),
                  ),
                ),
              ),
            if (digital > 0)
              Transform.translate(
                offset: Offset(0, (1 - digital) * 16 - 2),
                child: SizedBox(
                  width: width * 0.32,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: reduced ? 1 : digital.clamp(0.001, 1),
                      child: Opacity(
                        opacity: digital.clamp(0, 1),
                        child: _Plate(
                          key: const Key('intro-digital'),
                          asset: GarraIntroAssets.digital,
                          width: width * 0.32,
                          alignment: const Alignment(0, 0.64),
                          heightFactor: 0.075,
                          sweep: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Opacity(
              opacity: claim.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, (1 - claim) * 8),
                child: Text(
                  'De hinchas para hinchas',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(GarraColors.cream),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _fade(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return Curves.easeOut.transform((t - start) / (end - start));
  }

  double _impact(double t) {
    final start = 2000 / 8800;
    final end = 2200 / 8800;
    if (t <= start || t >= end) return 0;
    return math.sin(((t - start) / (end - start)) * math.pi);
  }
}

class _Plate extends StatelessWidget {
  const _Plate({
    super.key,
    required this.asset,
    required this.width,
    required this.alignment,
    required this.heightFactor,
    required this.sweep,
  });

  final String asset;
  final double width;
  final Alignment alignment;
  final double heightFactor;
  final double sweep;

  static const _lumaToAlpha = ColorFilter.matrix(<double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0.25,
    0.65,
    0.10,
    0,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRect(
              child: Align(
                alignment: alignment,
                heightFactor: heightFactor,
                child: ColorFiltered(
                  colorFilter: _lumaToAlpha,
                  child: Image(
                    image: ResizeImage(AssetImage(asset), width: 720),
                    fit: BoxFit.fitWidth,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            if (sweep > 0 && sweep < 1)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _SweepPainter(sweep)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * (-0.35 + 1.5 * t);
    final rect = Rect.fromLTWH(x, 0, size.width * 0.22, size.height);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        rect.centerLeft,
        rect.centerRight,
        const [Color(0x00C7A45B), Color(0x99C7A45B), Color(0x00C7A45B)],
        const [0, 0.5, 1],
      );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.45);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) => oldDelegate.t != t;
}

class _HazePainter extends CustomPainter {
  const _HazePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
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
