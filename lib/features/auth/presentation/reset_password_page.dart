import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/auth_flow_models.dart';
import 'providers/auth_flow_providers.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_flow_widgets.dart';

/// RESET PASSWORD: code + new password (+ confirmation) -> login.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.args});

  final ResetPasswordArgs args;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final ResendCountdown _countdown;
  bool _submitting = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _countdown = ResendCountdown(
      onTick: () {
        if (mounted) setState(() {});
      },
    )..start(widget.args.resendAvailableInSeconds);
  }

  @override
  void dispose() {
    _countdown.dispose();
    // Sensitive controllers are cleared before they are released.
    _passwordController.clear();
    _confirmController.clear();
    _codeController.clear();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_codeController.text.trim().length != 6) {
      setState(() => _error = 'Ingresa el c\u00f3digo de 6 d\u00edgitos.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!allowNetworkAction(context)) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final authService = ref.read(authServiceProvider);

    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await authService.resetPassword(
      email: widget.args.email,
      code: _codeController.text,
      newPassword: _passwordController.text,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _submitting = false;
        _error = result.message;
      });
      return;
    }
    _passwordController.clear();
    _confirmController.clear();
    _codeController.clear();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Contrase\u00f1a actualizada. Inicia sesi\u00f3n con tu nueva contrase\u00f1a.',
          ),
        ),
      );
    router.go('/login');
  }

  Future<void> _resend() async {
    if (_resending || _countdown.active) return;
    if (!allowNetworkAction(context)) return;

    final messenger = ScaffoldMessenger.of(context);
    final authService = ref.read(authServiceProvider);

    setState(() {
      _resending = true;
      _error = null;
    });
    final result = await authService.forgotPassword(widget.args.email);
    if (!mounted) return;

    setState(() => _resending = false);
    if (result.success) {
      _countdown.start(result.data?.resendAvailableInSeconds ?? 60);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text(authNeutralAcceptedMessage)),
        );
      return;
    }
    if (result.kind == AuthFailureKind.rateLimited &&
        result.retryAfterSeconds != null) {
      _countdown.start(result.retryAfterSeconds!);
    }
    setState(() => _error = result.message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final masked = maskEmail(widget.args.email);
    return AuthFlowScaffold(
      title: 'Nueva contrase\u00f1a',
      subtitle:
          'Si existe una cuenta asociada a $masked, enviamos un c\u00f3digo '
          'de 6 d\u00edgitos. Escr\u00edbelo y elige tu nueva contrase\u00f1a.',
      onBack: _submitting ? null : () => context.go('/forgot-password'),
      children: [
        OtpCodeField(
          controller: _codeController,
          enabled: !_submitting,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: GarraSpacing.lg),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthPasswordField(
                label: 'Nueva contrase\u00f1a',
                controller: _passwordController,
                enabled: !_submitting,
                helper: authPasswordRequirement(),
                fieldKey: const ValueKey('reset-password'),
                validator: validateNewPassword,
              ),
              const SizedBox(height: GarraSpacing.lg),
              AuthPasswordField(
                label: 'Confirmar contrase\u00f1a',
                controller: _confirmController,
                enabled: !_submitting,
                textInputAction: TextInputAction.done,
                fieldKey: const ValueKey('reset-confirm'),
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
          label: 'Cambiar contrase\u00f1a',
          loading: _submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: GarraSpacing.lg),
        Text(
          _countdown.active
              ? 'Podr\u00e1s solicitar otro c\u00f3digo en ${_countdown.label}'
              : 'Puedes solicitar un nuevo c\u00f3digo.',
          key: const ValueKey('resend-hint'),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: GarraSpacing.sm),
        GarraSecondaryButton(
          label: 'Reenviar c\u00f3digo',
          onPressed: (_countdown.active || _resending || _submitting)
              ? null
              : _resend,
        ),
      ],
    );
  }
}
