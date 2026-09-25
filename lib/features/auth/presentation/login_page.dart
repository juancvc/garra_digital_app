import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/garra_puma_crest.dart';
import '../../notifications/data/push_session_coordinator.dart';
import 'providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    final authService = ref.read(authServiceProvider);

    final result = await authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() => _loading = false);

    if (result.success) {
      await pushSessionCoordinator.afterAuthenticated();
      if (!mounted) return;
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFFB33A3A),
        ),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.loginWithGoogle();

    setState(() => _loading = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFFB33A3A),
        ),
      );
      return;
    }

    final status = result.user?.status;

    if (status == 'PENDING_PROFILE') {
      context.go('/complete-profile');
    } else {
      await pushSessionCoordinator.afterAuthenticated();
      if (!mounted) return;
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.background),
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/visual/garra_stadium_splash.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            colorFilter: ColorFilter.mode(
              const Color(GarraColors.background).withValues(alpha: 0.94),
              BlendMode.srcATop,
            ),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xE647101C),
              Color(0xF20E0C0B),
              Color(GarraColors.background),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hero = constraints.maxHeight * 0.31;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 36,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(minHeight: hero),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const GarraPumaCrest(size: 76),
                                const SizedBox(height: 12),
                                const Text(
                                  'GARRA DIGITAL',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.cream,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'De hinchas para hinchas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(GarraColors.cream),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Comunidad no oficial de hinchas cremas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(GarraColors.creamMuted),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(GarraColors.surface),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  GarraColors.gold,
                                ).withValues(alpha: 0.18),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                22,
                                20,
                                12,
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) =>
                                        _loading ? null : _login(),
                                    decoration: const InputDecoration(
                                      labelText: 'Contraseña',
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: _loading ? null : _login,
                                      child: _loading
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Iniciar sesión'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Row(
                                    children: [
                                      Expanded(child: Divider()),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          'o',
                                          style: TextStyle(
                                            color: Color(
                                              GarraColors.creamMuted,
                                            ),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _loading
                                          ? null
                                          : _loginWithGoogle,
                                      child: const Text('Continuar con Google'),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.go('/register'),
                                    child: const Text(
                                      'Crear cuenta',
                                      style: TextStyle(color: AppTheme.gold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
