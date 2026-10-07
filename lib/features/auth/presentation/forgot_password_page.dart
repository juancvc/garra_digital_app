import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/navigation/auth_back.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_ui.dart';
import 'providers/auth_flow_providers.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_flow_widgets.dart';

/// FORGOT PASSWORD: e-mail -> request. The copy never says whether the
/// account exists; the server answers identically either way.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!allowNetworkAction(context)) return;

    final router = GoRouter.of(context);
    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await authService.forgotPassword(email);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }
    setState(() => _loading = false);
    router.go(
      '/reset-password',
      extra: ResetPasswordArgs(
        email: email,
        resendAvailableInSeconds: result.data?.resendAvailableInSeconds ?? 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GarraAuthRouteScope(
      fallback: '/login',
      child: AuthFlowScaffold(
        title: '\u00bfOlvidaste tu contrase\u00f1a?',
        subtitle:
            'Escribe tu correo. Si existe una cuenta asociada, '
            'te enviaremos un c\u00f3digo para crear una nueva contrase\u00f1a.',
        onBack: _loading
            ? null
            : () => authNavigateBack(context, fallback: '/login'),
        children: [
          Form(
            key: _formKey,
            child: GarraTextField(
              label: 'Correo electr\u00f3nico',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              fieldKey: const ValueKey('forgot-email'),
              validator: (value) {
                final text = value?.trim() ?? '';
                final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
                return ok ? null : 'Ingresa un correo v\u00e1lido';
              },
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          if (_error != null) AuthInlineError(message: _error!),
          GarraPrimaryButton(
            label: 'Enviar c\u00f3digo',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
