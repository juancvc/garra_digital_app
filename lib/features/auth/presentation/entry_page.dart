import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_radius.dart';
import 'providers/auth_flow_providers.dart';
import 'providers/auth_provider.dart';
import 'widgets/garra_auth_entry_layout.dart';
import 'widgets/garra_google_sign_in_button.dart';

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

    if (result.cancelled) {
      setState(() => _loading = false);
      return;
    }

    final user = result.user;
    if (!result.success || user == null) {
      setState(() => _loading = false);
      if (result.message.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(result.message)));
      }
      return;
    }

    final route = await postAuthRoute(destinationFor, user, next: next);
    if (!mounted) return;
    setState(() => _loading = false);
    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    const heroText = Color(0xFFF7F0E2);
    const heroSecondary = Color(0xFFE8DED0);
    return GarraAuthEntryLayout(
      heroTitle: '\u00daNETE A GARRA',
      heroSubtitle: 'La comunidad digital de la hinchada crema.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GarraGoogleSignInButton(
            label: 'Continuar con Google',
            loading: _loading,
            primary: true,
            onPressed: _loading ? null : _continueWithGoogle,
          ),
          const SizedBox(height: GarraSpacing.md),
          Row(
            children: [
              Expanded(
                child: Divider(color: heroSecondary.withValues(alpha: 0.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.md,
                ),
                child: const Text('o', style: TextStyle(color: heroSecondary)),
              ),
              Expanded(
                child: Divider(color: heroSecondary.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: GarraSpacing.md),
          OutlinedButton(
            onPressed: _loading ? null : () => context.push('/register'),
            style: OutlinedButton.styleFrom(
              foregroundColor: heroText,
              side: BorderSide(color: heroText.withValues(alpha: 0.6)),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GarraRadius.md),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: heroText,
                ),
                const SizedBox(width: GarraSpacing.sm),
                const Flexible(
                  child: Text(
                    'Crear cuenta con correo',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          TextButton(
            key: const ValueKey('entry-login'),
            onPressed: _loading ? null : () => context.push('/login'),
            child: Text(
              '\u00bfYa tienes una cuenta? Inicia sesi\u00f3n',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE7C879)),
            ),
          ),
        ],
      ),
    );
  }
}
