import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_ui.dart';
import 'providers/auth_flow_providers.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_flow_widgets.dart';
import 'widgets/garra_auth_entry_layout.dart';
import 'widgets/garra_google_sign_in_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _passwordResetNoticeShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Success flash from password reset: shown here so the SnackBar binds to
    // the login Scaffold, never to a page that is about to be disposed.
    if (_passwordResetNoticeShown) return;
    final resetQuery =
        GoRouter.maybeOf(context)?.state.uri.queryParameters['passwordReset'];
    if (resetQuery != '1') {
      return;
    }
    _passwordResetNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contrase\u00f1a actualizada. Inicia sesi\u00f3n con tu nueva contrase\u00f1a.',
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  SnackBar _errorSnackBar(String message) => SnackBar(
    content: Text(message),
    backgroundColor: const Color(0xFFB33A3A),
  );

  /// Lifecycle contract (GARRA39): the messenger, router and `next` target are
  /// captured before the `await`; after it only `mounted` and those captured
  /// objects are used, never a fresh lookup through this State's context.
  Future<void> _login() async {
    if (_loading) return;
    if (!allowNetworkAction(context)) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    final authService = ref.read(authServiceProvider);
    final destinationFor = ref.read(postAuthDestinationProvider);
    final email = _emailController.text.trim();

    setState(() => _loading = true);

    final result = await authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    final user = result.user;
    if (result.success && user != null) {
      // One shared post-auth decision (profile pending -> Garra profile ->
      // onboarding -> Home).
      final route = await postAuthRoute(destinationFor, user, next: next);
      if (!mounted) return;
      router.go(route);
    } else if (result.requiresEmailVerification) {
      // Typed state from the server (never inferred from the message).
      _passwordController.clear();
      router.go(
        '/verify-email',
        extra: VerifyEmailArgs(email: email, fromLogin: true),
      );
    } else {
      messenger.showSnackBar(_errorSnackBar(result.message));
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_loading) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    final authService = ref.read(authServiceProvider);
    final destinationFor = ref.read(postAuthDestinationProvider);

    setState(() => _loading = true);

    final result = await authService.loginWithGoogle();

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.cancelled) return;

    final user = result.user;
    if (!result.success || user == null) {
      if (result.message.isNotEmpty) {
        messenger.showSnackBar(_errorSnackBar(result.message));
      }
      return;
    }

    final route = await postAuthRoute(destinationFor, user, next: next);
    if (!mounted) return;
    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return GarraAuthEntryLayout(
      heroTitle: 'Inicia sesi\u00f3n',
      heroSubtitle: 'Bienvenido de vuelta a Garra Digital.',
      body: GarraAuthFormCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GarraTextField(
              label: 'Correo electr\u00f3nico',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              fieldKey: const ValueKey('login-email'),
            ),
            const SizedBox(height: GarraSpacing.md),
            AuthPasswordField(
              label: 'Contrase\u00f1a',
              controller: _passwordController,
              enabled: !_loading,
              textInputAction: TextInputAction.done,
              fieldKey: const ValueKey('login-password'),
            ),
            const SizedBox(height: GarraSpacing.lg),
            GarraPrimaryButton(
              label: 'Iniciar sesi\u00f3n',
              loading: _loading,
              onPressed: _loading ? null : _login,
            ),
            TextButton(
              key: const ValueKey('forgot-password-link'),
              onPressed: _loading
                  ? null
                  : () => context.go(
                      '/forgot-password',
                      extra: _emailController.text.trim(),
                    ),
              child: const Text(
                '\u00bfOlvidaste tu contrase\u00f1a?',
                style: TextStyle(color: AppTheme.gold),
              ),
            ),
            Row(
              children: [
                Expanded(child: Divider(color: colors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.md),
                  child: Text('o', style: TextStyle(color: colors.textSecondary)),
                ),
                Expanded(child: Divider(color: colors.border)),
              ],
            ),
            const SizedBox(height: GarraSpacing.sm),
            GarraGoogleSignInButton(
              label: 'Continuar con Google',
              loading: _loading,
              onPressed: _loading ? null : _loginWithGoogle,
            ),
            TextButton(
              key: const ValueKey('login-register-link'),
              onPressed: _loading ? null : () => context.go('/register'),
              child: Text(
                '\u00bfNo tienes una cuenta? Crear cuenta',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.brandPrestige),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
