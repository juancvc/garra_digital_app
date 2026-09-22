import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/widgets/garra_brand_visual.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _storage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 900));

    final hasToken = await _storage.hasToken();

    if (!mounted) return;

    if (hasToken) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.background),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/visual/garra_stadium_splash.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(GarraColors.background)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x700E0C0B),
                  Color(0x30170D10),
                  Color(0xE80E0C0B),
                ],
                stops: [0, 0.46, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.18),
                radius: 0.86,
                colors: [
                  const Color(GarraColors.burgundy).withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 360
                    ? 18.0
                    : 28.0;
                final crestSize = (constraints.maxWidth * 0.35).clamp(
                  104.0,
                  138.0,
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight > 40
                          ? constraints.maxHeight - 40
                          : 0,
                    ),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0, end: 1),
                        child: _SplashContent(crestSize: crestSize),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.scale(
                              scale: 0.96 + (value * 0.04),
                              child: child,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({required this.crestSize});

  final double crestSize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label:
          'Garra Digital, comunidad no oficial de hinchas cremas. '
          'La pasión crema vive aquí.',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GarraCrest(size: crestSize, showGlow: true),
              const SizedBox(height: 24),
              Text(
                'GARRA DIGITAL',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  color: const Color(GarraColors.cream),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'COMUNIDAD NO OFICIAL DE HINCHAS CREMAS',
                textAlign: TextAlign.center,
                style: textTheme.labelSmall?.copyWith(
                  color: const Color(GarraColors.gold),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.05,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: 42,
                height: 1,
                color: const Color(GarraColors.gold).withValues(alpha: 0.7),
              ),
              const SizedBox(height: 20),
              Text(
                'La pasión crema vive aquí',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  color: const Color(GarraColors.textPrimary),
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hecho por hinchas, para hinchas',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(GarraColors.textSecondary),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
