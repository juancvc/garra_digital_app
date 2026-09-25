import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/utils/country_labels.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/passport_models.dart';
import 'providers/passport_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, this.media});

  final MediaUploadService? media;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _bio;
  late final TextEditingController _city;
  late final TextEditingController _year;
  late final MediaUploadService _media;
  String _visibility = 'PUBLIC';
  String _country = 'PE';
  String? _avatarUrl;
  String? _avatarAssetId;
  bool _uploadingPhoto = false;
  bool _loading = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController();
    _bio = TextEditingController();
    _city = TextEditingController();
    _year = TextEditingController();
    _media = widget.media ?? MediaUploadService();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    _city.dispose();
    _year.dispose();
    super.dispose();
  }

  void _seed(PassportModel passport) {
    if (_seeded) return;
    _seeded = true;
    _displayName.text = passport.identity.displayName;
    _bio.text = passport.identity.bio ?? '';
    _city.text = passport.identity.city ?? '';
    _country = (passport.identity.countryCode ?? 'PE').toUpperCase();
    if (!garraCountries.any((c) => c.$1 == _country)) {
      _country = 'PE';
    }
    _year.text = passport.identity.supporterSinceYear?.toString() ?? '';
    _visibility = passport.profileVisibility;
    _avatarUrl = passport.identity.avatarUrl;
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final file = source == ImageSource.camera
          ? await _media.pickCamera(maxSide: 1024)
          : await _media.pickImage(maxSide: 1024);
      if (file == null) return;
      final draft = await _media.uploadAvatar(file);
      if (!mounted) return;
      if (!draft.isReady) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos cargar la foto')),
        );
        return;
      }
      setState(() {
        _avatarAssetId = draft.assetId;
        _avatarUrl = draft.mediaUrl ?? _avatarUrl;
        _uploadingPhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos cargar la foto')),
      );
    }
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
              countryCode: _country,
              supporterSinceYear:
                  yearText.isEmpty ? null : int.tryParse(yearText),
              profileVisibility: _visibility,
              avatarMediaAssetId: _avatarAssetId,
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
          message: 'Inténtalo de nuevo.',
          onRetry: () => ref.invalidate(myPassportProvider),
        ),
        data: (PassportModel passport) {
          _seed(passport);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.xl,
              ),
              children: [
                Center(
                  child: Column(
                    children: [
                      GarraAvatar(
                        displayName: _displayName.text.isEmpty
                            ? passport.identity.displayName
                            : _displayName.text,
                        avatarUrl: _avatarUrl,
                        size: 96,
                      ),
                      TextButton(
                        key: const ValueKey('change-avatar'),
                        onPressed: _uploadingPhoto ? null : _changePhoto,
                        child: Text(
                          _uploadingPhoto ? 'Subiendo foto…' : 'Cambiar foto',
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _displayName,
                  decoration: const InputDecoration(
                    labelText: 'Nombre visible',
                    isDense: true,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length < 2) return 'Mínimo 2 caracteres';
                    if (v.length > 120) return 'Máximo 120 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.sm),
                TextFormField(
                  controller: _bio,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: GarraSpacing.sm),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    isDense: true,
                  ),
                  validator: (value) {
                    if ((value ?? '').length > 80) {
                      return 'Máximo 80 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.sm),
                DropdownButtonFormField<String>(
                  key: ValueKey('country-$_country'),
                  initialValue: _country,
                  decoration: const InputDecoration(
                    labelText: 'País',
                    isDense: true,
                  ),
                  items: [
                    for (final country in garraCountries)
                      DropdownMenuItem(
                        value: country.$1,
                        child: Text(country.$2),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _country = value);
                  },
                ),
                const SizedBox(height: GarraSpacing.sm),
                TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Crema desde',
                    helperText: 'Año en que empezaste a alentar. Ejemplo: 2012',
                    isDense: true,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return null;
                    final year = int.tryParse(v);
                    final now = DateTime.now().year;
                    if (year == null || year < 1900 || year > now) {
                      return 'Año no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.sm),
                DropdownButtonFormField<String>(
                  key: ValueKey('visibility-$_visibility'),
                  initialValue: _visibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibilidad',
                    isDense: true,
                  ),
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
                const SizedBox(height: GarraSpacing.lg),
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
