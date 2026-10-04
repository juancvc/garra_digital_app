import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garra_digital_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:garra_digital_app/features/matches/presentation/providers/matches_provider.dart';
import 'package:garra_digital_app/features/predictions/presentation/providers/prediction_provider.dart';
import 'package:garra_digital_app/features/ranking/presentation/providers/ranking_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/auth_flow_models.dart';
import '../data/google_auth_service.dart';
import 'providers/auth_flow_providers.dart';
import 'widgets/auth_flow_widgets.dart';

/// PERFIL GARRA: the one place every sign-in method ends in (Google, e-mail+OTP,
/// future providers). Visible name, @usuario, tribuna, the declaration of
/// adhesion and the community guidelines. The server is the authority: it
/// refuses the call unless both acceptances are sent.
class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  String? _tribuna;
  bool _fanDeclaration = false;
  bool _guidelines = false;
  bool _loading = false;
  bool _triedSubmit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillName();
  }

  /// Google (or the registration) may already know a name; offer it, editable.
  Future<void> _prefillName() async {
    final user = await ref.read(authServiceProvider).me();
    if (!mounted || user == null) return;
    final name = user.fullName.trim();
    if (name.isNotEmpty &&
        name != pendingFullNamePlaceholder &&
        _nameController.text.isEmpty) {
      _nameController.text = name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final router = GoRouter.of(context);
    await GoogleAuthService().signOut();
    await SecureStorageService().clearAll();
    if (!mounted) return;
    router.go('/welcome');
  }

  /// Lifecycle contract (GARRA39): everything that needs the context is
  /// captured before the `await`; afterwards only `mounted` and those objects.
  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _triedSubmit = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tribuna == null || !_fanDeclaration || !_guidelines) return;

    final router = GoRouter.of(context);
    final authService = ref.read(authServiceProvider);
    final destinationFor = ref.read(postAuthDestinationProvider);

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await authService.completeProfile(
      username: _usernameController.text,
      fullName: _nameController.text,
      favoriteStand: _tribuna!,
      cremaDeclarationAccepted: _fanDeclaration,
      communityGuidelinesAccepted: _guidelines,
    );
    if (!mounted) return;

    final user = result.data;
    if (!result.success || user == null) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    ref.invalidate(currentUserProvider);
    ref.invalidate(rankingProvider);
    ref.invalidate(upcomingMatchesProvider);
    ref.invalidate(myPredictionsProvider);

    // GARRA38: the skippable social onboarding follows the Garra profile once.
    final route = await destinationFor(user);
    if (!mounted) return;
    setState(() => _loading = false);
    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final text = Theme.of(context).textTheme;
    final standMissing = _triedSubmit && _tribuna == null;
    final declarationMissing = _triedSubmit && !_fanDeclaration;
    final guidelinesMissing = _triedSubmit && !_guidelines;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              key: const ValueKey('profile-logout'),
              tooltip: 'Salir',
              icon: Icon(Icons.logout_rounded, color: colors.textPrimary),
              onPressed: _loading ? null : _logout,
            ),
          ],
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Completa tu perfil crema.',
                        key: const ValueKey('profile-title'),
                        textAlign: TextAlign.center,
                        style: text.headlineSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      Text(
                        'Cu\u00e9ntanos c\u00f3mo vives la U.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: GarraSpacing.xxl),
                      GarraTextField(
                        label: 'Nombre visible',
                        controller: _nameController,
                        fieldKey: const ValueKey('profile-name'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final t = value?.trim() ?? '';
                          if (t.length < 2) return 'Escribe tu nombre';
                          if (t.length > 120)
                            return 'M\u00e1ximo 120 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: GarraSpacing.lg),
                      GarraTextField(
                        label: 'Nombre de usuario (@usuario)',
                        controller: _usernameController,
                        fieldKey: const ValueKey('profile-username'),
                        validator: (value) {
                          final t = value?.trim() ?? '';
                          if (t.length < 3)
                            return 'Debe tener al menos 3 caracteres';
                          if (t.length > 60) return 'M\u00e1ximo 60 caracteres';
                          if (t.contains(' ')) {
                            return 'El usuario no debe tener espacios';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: GarraSpacing.lg),
                      const GarraFieldLabel('Tribuna preferida'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final stand in garraStands)
                            ChoiceChip(
                              key: ValueKey('stand-$stand'),
                              label: Text(stand),
                              selected: _tribuna == stand,
                              onSelected: _loading
                                  ? null
                                  : (_) => setState(() => _tribuna = stand),
                            ),
                        ],
                      ),
                      if (standMissing)
                        Padding(
                          padding: const EdgeInsets.only(top: GarraSpacing.sm),
                          child: Text(
                            'Elige tu tribuna preferida',
                            key: const ValueKey('stand-error'),
                            style: TextStyle(
                              color: colors.danger,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: GarraSpacing.xl),
                      Text(
                        'Garra es una comunidad creada para hinchas de Universitario.',
                        key: const ValueKey('membership-intro'),
                        style: text.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      _AcceptanceTile(
                        tileKey: const ValueKey('accept-fan'),
                        value: _fanDeclaration,
                        enabled: !_loading,
                        label:
                            'Soy hincha de Universitario y quiero formar parte de Garra.',
                        error: declarationMissing
                            ? 'Marca esta casilla para continuar'
                            : null,
                        onChanged: (v) => setState(() => _fanDeclaration = v),
                      ),
                      _AcceptanceTile(
                        tileKey: const ValueKey('accept-guidelines'),
                        value: _guidelines,
                        enabled: !_loading,
                        label:
                            'Me comprometo a respetar las normas de convivencia de la comunidad.',
                        error: guidelinesMissing
                            ? 'Marca esta casilla para continuar'
                            : null,
                        onChanged: (v) => setState(() => _guidelines = v),
                      ),
                      const SizedBox(height: GarraSpacing.lg),
                      if (_error != null) AuthInlineError(message: _error!),
                      GarraPrimaryButton(
                        label: 'Entrar a Garra',
                        loading: _loading,
                        onPressed: _loading ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptanceTile extends StatelessWidget {
  const _AcceptanceTile({
    required this.tileKey,
    required this.value,
    required this.label,
    required this.onChanged,
    required this.enabled,
    this.error,
  });

  final Key tileKey;
  final bool value;
  final String label;
  final String? error;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          key: tileKey,
          value: value,
          enabled: enabled,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => onChanged(v ?? false),
          title: Text(
            label,
            style: TextStyle(color: colors.textPrimary, height: 1.3),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              error!,
              style: TextStyle(color: colors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
