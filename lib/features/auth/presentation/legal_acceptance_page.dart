import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/legal/legal_acceptance_checkbox.dart';
import '../../../core/legal/legal_acceptance_service.dart';
import '../../../core/widgets/garra_ui.dart';
import 'providers/auth_flow_providers.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_flow_widgets.dart';

/// Where the gate continues after a successful acceptance. Overridable in tests.
final postLegalDestinationProvider = Provider<Future<String> Function()>(
  (ref) => postLegalDestination,
);

/// PLAY-02: client-side gate for existing users who have not accepted the
/// current Terms/Privacy versions (channel UPDATE_PROMPT). The checkbox is
/// never pre-checked; the user can also sign out.
class LegalAcceptancePage extends ConsumerStatefulWidget {
  const LegalAcceptancePage({super.key});

  @override
  ConsumerState<LegalAcceptancePage> createState() =>
      _LegalAcceptancePageState();
}

class _LegalAcceptancePageState extends ConsumerState<LegalAcceptancePage> {
  bool _accepted = false;
  bool _tried = false;
  bool _loading = false;
  String? _error;

  Future<void> _continue() async {
    if (_loading) return;
    setState(() => _tried = true);
    if (!_accepted) return;
    final router = GoRouter.of(context);
    final service = ref.read(legalAcceptanceServiceProvider);
    final next = ref.read(postLegalDestinationProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await service.accept(LegalAcceptanceChannel.updatePrompt);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No pudimos registrar tu aceptaci\u00f3n. Int\u00e9ntalo de nuevo.';
      });
      return;
    }
    final route = await next();
    if (!mounted) return;
    setState(() => _loading = false);
    router.go(route);
  }

  Future<void> _logout() async {
    final router = GoRouter.of(context);
    await ref.read(authServiceProvider).logout();
    if (!mounted) return;
    router.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const ValueKey('legal-acceptance-page'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Actualizamos nuestros t\u00e9rminos',
                style: text.titleLarge,
              ),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                'Para seguir usando Garra, revisa y acepta los T\u00e9rminos y la Pol\u00edtica de privacidad.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: GarraSpacing.md),
              LegalAcceptanceCheckbox(
                value: _accepted,
                enabled: !_loading,
                error: _tried && !_accepted
                    ? 'Marca esta casilla para continuar'
                    : null,
                onChanged: (v) => setState(() => _accepted = v),
              ),
              const SizedBox(height: GarraSpacing.lg),
              if (_error != null) AuthInlineError(message: _error!),
              GarraPrimaryButton(
                key: const ValueKey('legal-accept-continue'),
                label: 'Aceptar y continuar',
                loading: _loading,
                onPressed: _loading ? null : _continue,
              ),
              TextButton(
                onPressed: _loading ? null : _logout,
                child: const Text('Cerrar sesi\u00f3n'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
