import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/garra_claw_mark.dart';
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
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/visual/garra_stadium_splash.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            colorFilter: ColorFilter.mode(
              const Color(GarraColors.background).withValues(alpha: 0.88),
              BlendMode.srcATop,
            ),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xCC47101C),
              Color(0xF00E0C0B),
              Color(GarraColors.background),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: GarraClawMark(size: 84),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'GARRA DIGITAL',
                      style: TextStyle(
                        color: AppTheme.cream,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'De hinchas para hinchas',
                      style: TextStyle(
                        color: Color(GarraColors.cream),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comunidad no oficial de hinchas cremas',
                      style: TextStyle(
                        color: Color(GarraColors.creamMuted),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 36),

                    Card(
                      color: Color(GarraColors.surface),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock),
                              ),
                            ),
                            const SizedBox(height: 24),
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

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _loginWithGoogle,
                                icon: const Icon(Icons.login),
                                label: const Text('Continuar con Google'),
                              ),
                            ),

                            const SizedBox(height: 16),
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
        ),
      ),
    );
  }
}
