import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/passport_models.dart';
import 'providers/passport_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _bio;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _year;
  String _visibility = 'PUBLIC';
  bool _loading = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController();
    _bio = TextEditingController();
    _city = TextEditingController();
    _country = TextEditingController();
    _year = TextEditingController();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    _city.dispose();
    _country.dispose();
    _year.dispose();
    super.dispose();
  }

  void _seed(PassportModel passport) {
    if (_seeded) return;
    _seeded = true;
    _displayName.text = passport.identity.displayName;
    _bio.text = passport.identity.bio ?? '';
    _city.text = passport.identity.city ?? '';
    _country.text = passport.identity.countryCode ?? 'PE';
    _year.text = passport.identity.supporterSinceYear?.toString() ?? '';
    _visibility = passport.profileVisibility;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final yearText = _year.text.trim();
      await ref.read(passportServiceProvider).updateMyProfile(
            ProfileUpdateRequest(
              displayName: _displayName.text.trim(),
              bio: _bio.text.trim(),
              city: _city.text.trim(),
              countryCode: _country.text.trim().toUpperCase(),
              supporterSinceYear:
                  yearText.isEmpty ? null : int.tryParse(yearText),
              profileVisibility: _visibility,
            ),
          );
      ref.invalidate(myPassportProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el perfil')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passportAsync = ref.watch(myPassportProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: passportAsync.when(
        loading: () => const GarraPassportSkeleton(),
        error: (error, stackTrace) => GarraErrorState(
          title: 'No pudimos cargar tu perfil',
          onRetry: () => ref.invalidate(myPassportProvider),
        ),
        data: (PassportModel passport) {
          _seed(passport);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              children: [
                const GarraFormIntro(
                  title: 'Tu perfil',
                  subtitle: 'Así te ven los demás hinchas. Los cambios se guardan al pulsar Guardar.',
                ),
                TextFormField(
                  controller: _displayName,
                  decoration: const InputDecoration(labelText: 'Nombre visible'),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length < 2) return 'Mínimo 2 caracteres';
                    if (v.length > 120) return 'Máximo 120 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.lg),
                TextFormField(
                  controller: _bio,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: GarraSpacing.lg),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                  validator: (value) {
                    if ((value ?? '').length > 80) return 'Máximo 80 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.lg),
                TextFormField(
                  controller: _country,
                  decoration: const InputDecoration(labelText: 'País (ISO-2)'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return null;
                    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(v)) {
                      return 'Usa código ISO de 2 letras (ej. PE)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.lg),
                TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Crema desde (año)',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return null;
                    final year = int.tryParse(v);
                    if (year == null || year < 1900 || year > 2100) {
                      return 'Año inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.lg),
                DropdownButtonFormField<String>(
                  key: ValueKey(_visibility),
                  initialValue: _visibility,
                  decoration: const InputDecoration(labelText: 'Visibilidad'),
                  items: const [
                    DropdownMenuItem(value: 'PUBLIC', child: Text('Público')),
                    DropdownMenuItem(
                      value: 'MEMBERS_ONLY',
                      child: Text('Solo miembros'),
                    ),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Privado')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _visibility = value);
                  },
                ),
                const SizedBox(height: GarraSpacing.xxl),
                GarraPrimaryButton(
                  label: 'Guardar cambios',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
