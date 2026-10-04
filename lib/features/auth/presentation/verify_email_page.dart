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

/// CHECK YOUR EMAIL -> ENTER CODE -> VERIFY. The backend owns expiry, attempts
/// and the resend cooldown; this screen only mirrors them.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, required this.args});

  final VerifyEmailArgs args;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _codeController = TextEditingController();
  late final ResendCountdown _countdown;
  bool _verifying = false;
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
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Ingresa el c\u00f3digo de 6 d\u00edgitos.');
      return;
    }
    if (!allowNetworkAction(context)) return;

    // Everything needed after the async gap is captured before it.
    final router = GoRouter.of(context);
    final authService = ref.read(authServiceProvider);
    final destinationFor = ref.read(postVerifyDestinationProvider);

    setState(() {
      _verifying = true;
      _error = null;
    });
    final result = await authService.verifyEmail(
      email: widget.args.email,
      code: code,
    );
    if (!mounted) return;

    final user = result.data;
    if (!result.success || user == null) {
      setState(() {
        _verifying = false;
        _error = result.message;
      });
      return;
    }

    final destination = await destinationFor(user);
    if (!mounted) return;
    _codeController.clear();
    router.go(destination);
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
    final result = await authService.resendVerification(widget.args.email);
    if (!mounted) return;

    setState(() => _resending = false);
    if (result.success) {
      _countdown.start(result.data?.resendAvailableInSeconds ?? 60);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Si el correo es correcto, te enviamos un nuevo c\u00f3digo.',
            ),
          ),
        );
      return;
    }
    if (result.kind == AuthFailureKind.rateLimited &&
        result.retryAfterSeconds != null) {
      _countdown.start(result.retryAfterSeconds!);
    }
    setState(() => _error = result.message);
  }

  void _backToForm() {
    context.go(widget.args.fromLogin ? '/login' : '/register');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final masked = maskEmail(widget.args.email);
    return AuthFlowScaffold(
      title: 'Revisa tu correo',
      subtitle:
          'Enviamos un c\u00f3digo de 6 d\u00edgitos a $masked. '
          'Escr\u00edbelo para activar tu cuenta.',
      onBack: _verifying ? null : _backToForm,
      children: [
        OtpCodeField(
          controller: _codeController,
          enabled: !_verifying,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: _verify,
        ),
        const SizedBox(height: GarraSpacing.lg),
        if (_error != null) AuthInlineError(message: _error!),
        GarraPrimaryButton(
          label: 'Verificar',
          loading: _verifying,
          onPressed: _verify,
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
          onPressed: (_countdown.active || _resending || _verifying)
              ? null
              : _resend,
        ),
        TextButton(
          key: const ValueKey('change-email'),
          onPressed: _verifying ? null : _backToForm,
          child: Text(
            widget.args.fromLogin
                ? 'Volver a iniciar sesi\u00f3n'
                : 'Cambiar correo',
            style: TextStyle(color: colors.brandPrestige),
          ),
        ),
      ],
    );
  }
}
