import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/register_request.dart';
import 'providers/auth_flow_providers.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_flow_widgets.dart';
import 'widgets/garra_auth_entry_layout.dart';

/// E-MAIL ENTRY: e-mail + password (+ confirmation) -> CHECK YOUR EMAIL ->
/// code -> Garra profile. Name, @usuario and tribuna are asked later, in the
/// same Garra profile every sign-in method ends in.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// REGISTER FORM -> REGISTER REQUEST -> CHECK YOUR EMAIL.
  ///
  /// Lifecycle contract (GARRA39 crash fix): nothing that depends on this
  /// State's [BuildContext] runs after the `await`. The messenger and router
  /// are captured while the widget is surely active, `mounted` is checked right
  /// after the gap, and when the page is already gone it neither shows a
  /// snackbar nor navigates (the user left on purpose).
  Future<void> _register() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!allowNetworkAction(context)) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await authService.register(
      RegisterRequest(email: email, password: _passwordController.text),
    );

    // The page may have been removed while the request was in flight.
    if (!mounted) return;

    setState(() => _loading = false);

    final outcome = result.data;
    if (result.success && outcome != null && outcome.verificationRequired) {
      // The password never travels past this point.
      _passwordController.clear();
      _confirmPasswordController.clear();
      router.go(
        '/verify-email',
        extra: VerifyEmailArgs(
          email: outcome.email,
          resendAvailableInSeconds: outcome.resendAvailableInSeconds,
        ),
      );
      return;
    }

    if (result.success) {
      // Legacy server (verification switched off): the account is usable.
      messenger.showSnackBar(
        const SnackBar(content: Text('Cuenta creada correctamente')),
      );
      router.go('/login');
      return;
    }

    // Recoverable: the message stays on screen (duplicate, 429, network, or
    // "e-mail registration not available yet, use Google").
    setState(() => _error = result.message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return GarraAuthEntryLayout(
      onBack: _loading ? null : () => context.go('/welcome'),
      heroTitle: 'Crear cuenta',
      heroSubtitle: 'Crea tu acceso con correo. Luego completas tu perfil crema.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GarraTextField(
                label: 'Correo electr\u00f3nico',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                fieldKey: const ValueKey('register-email'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  final ok = RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(text);
                  return ok ? null : 'Ingresa un correo v\u00e1lido';
                },
              ),
              const SizedBox(height: GarraSpacing.lg),
              AuthPasswordField(
                label: 'Contrase\u00f1a',
                controller: _passwordController,
                enabled: !_loading,
                helper: authPasswordRequirement(),
                fieldKey: const ValueKey('register-password'),
                validator: validateNewPassword,
              ),
              const SizedBox(height: GarraSpacing.lg),
              AuthPasswordField(
                label: 'Confirmar contrase\u00f1a',
                controller: _confirmPasswordController,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                fieldKey: const ValueKey('register-confirm'),
                validator: (value) => value == _passwordController.text
                    ? null
                    : 'Las contrase\u00f1as no coinciden',
              ),
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.lg),
        if (_error != null) AuthInlineError(message: _error!),
        GarraPrimaryButton(
          label: 'Crear cuenta',
          loading: _loading,
          onPressed: _loading ? null : _register,
        ),
        const SizedBox(height: GarraSpacing.md),
        TextButton(
          onPressed: _loading ? null : () => context.go('/login'),
          child: Text(
            '\u00bfYa tienes una cuenta? Inicia sesi\u00f3n',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.brandPrestige),
          ),
        ),
        ],
      ),
    );
  }
}
