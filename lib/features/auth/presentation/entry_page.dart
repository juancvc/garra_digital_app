import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_puma_crest.dart';
import '../../../core/widgets/garra_ui.dart';
import 'providers/auth_flow_providers.dart';
import 'providers/auth_provider.dart';

/// GARRA39.1 entry: every method (Google today, e-mail now, others later)
/// proves identity and then converges on the same journey: Garra profile ->
/// onboarding -> Home. Only methods that really work are shown.
class EntryPage extends ConsumerStatefulWidget {
  const EntryPage({super.key});

  @override
  ConsumerState<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends ConsumerState<EntryPage> {
  bool _loading = false;

  /// Lifecycle contract (GARRA39): messenger, router and the services are
  /// captured before the `await`; afterwards only `mounted` and those captured
  /// objects are used.
  Future<void> _continueWithGoogle() async {
    if (_loading) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    final authService = ref.read(authServiceProvider);
    final destinationFor = ref.read(postAuthDestinationProvider);

    setState(() => _loading = true);
    final result = await authService.loginWithGoogle();
    if (!mounted) return;

    final user = result.user;
    if (!result.success || user == null) {
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    final route = await postAuthRoute(destinationFor, user, next: next);
    if (!mounted) return;
    setState(() => _loading = false);
    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GarraSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: GarraPumaCrest(size: 84)),
                  const SizedBox(height: GarraSpacing.lg),
                  Text(
                    '\u00daNETE A GARRA',
                    key: const ValueKey('entry-title'),
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.sm),
                  Text(
                    'La comunidad digital de la hinchada crema.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.xxl),
                  GarraPrimaryButton(
                    label: 'Continuar con Google',
                    loading: _loading,
                    onPressed: _loading ? null : _continueWithGoogle,
                  ),
                  const SizedBox(height: GarraSpacing.md),
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: GarraSpacing.md,
                        ),
                        child: Text(
                          'o',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                      Expanded(child: Divider(color: colors.border)),
                    ],
                  ),
                  const SizedBox(height: GarraSpacing.md),
                  GarraSecondaryButton(
                    label: 'Continuar con correo',
                    onPressed: _loading ? null : () => context.go('/register'),
                  ),
                  const SizedBox(height: GarraSpacing.lg),
                  TextButton(
                    key: const ValueKey('entry-login'),
                    onPressed: _loading ? null : () => context.go('/login'),
                    child: Text(
                      '\u00bfYa tienes una cuenta? Inicia sesi\u00f3n',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.brandPrestige),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
