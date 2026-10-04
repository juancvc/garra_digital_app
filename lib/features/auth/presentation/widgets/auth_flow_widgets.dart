import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_form.dart';

/// Shared frame of the account-flow screens (verify, forgot, reset). Uses the
/// semantic Garra colors, so it follows Noche and Crema, and scrolls so a
/// narrow screen or the keyboard never overflows.
class AuthFlowScaffold extends StatelessWidget {
  const AuthFlowScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: onBack == null
            ? null
            : IconButton(
                key: const ValueKey('auth-flow-back'),
                tooltip: 'Volver',
                icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
                onPressed: onBack,
              ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.sm,
              GarraSpacing.lg,
              GarraSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.sm),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.xxl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline, recoverable error under a form (network, 429, wrong code...).
class AuthInlineError extends StatelessWidget {
  const AuthInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colors.danger),
          const SizedBox(width: GarraSpacing.sm),
          Expanded(
            child: Text(
              message,
              key: const ValueKey('auth-inline-error'),
              style: TextStyle(color: colors.danger, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Six-digit one-time code input: numeric keyboard, digits only, never copied
/// anywhere by the app.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.onChanged,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return TextField(
      key: const ValueKey('otp-field'),
      controller: controller,
      enabled: enabled,
      autofocus: false,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.center,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 10,
      ),
      decoration: garraControlDecoration(context).copyWith(
        counterText: '',
        hintText: '\u2022 \u2022 \u2022 \u2022 \u2022 \u2022',
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

/// Password field with visibility toggle. The caller owns (and clears) the
/// controller; nothing here logs or persists the value.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.helper,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final String? helper;
  final bool enabled;
  final TextInputAction textInputAction;
  final Key? fieldKey;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GarraFieldLabel(widget.label),
        TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscure,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          style: TextStyle(color: colors.textPrimary, fontSize: 16),
          decoration: garraControlDecoration(context, helper: widget.helper)
              .copyWith(
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? 'Mostrar contrase\u00f1a'
                      : 'Ocultar contrase\u00f1a',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: colors.textSecondary,
                  ),
                ),
              ),
        ),
      ],
    );
  }
}

/// Seconds-based countdown for the resend cooldown. The server stays the
/// authority: this only mirrors the cooldown it announced.
class ResendCountdown {
  ResendCountdown({required this.onTick});

  final VoidCallback onTick;
  Timer? _timer;
  int remaining = 0;

  bool get active => remaining > 0;

  void start(int seconds) {
    _timer?.cancel();
    remaining = seconds < 0 ? 0 : seconds;
    if (remaining == 0) {
      onTick();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= 1;
      if (remaining <= 0) {
        remaining = 0;
        timer.cancel();
      }
      onTick();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  String get label {
    final minutes = remaining ~/ 60;
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

String authPasswordRequirement() => 'Entre 8 y 120 caracteres.';

String? validateNewPassword(String? value) {
  final text = value ?? '';
  if (text.length < 8) {
    return 'La contrase\u00f1a debe tener m\u00ednimo 8 caracteres';
  }
  if (text.length > 120) {
    return 'La contrase\u00f1a no puede superar 120 caracteres';
  }
  return null;
}
