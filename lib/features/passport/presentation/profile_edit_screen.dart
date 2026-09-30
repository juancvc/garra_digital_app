import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/navigation/draft_exit_guard.dart';
import '../../../core/utils/country_labels.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_sheet.dart';
import '../../../core/widgets/garra_states.dart';
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
  late final TextEditingController _instagram;
  late final TextEditingController _tiktok;
  late final TextEditingController _youtube;
  late final MediaUploadService _media;
  String _visibility = 'PUBLIC';
  String _country = 'PE';
  String? _avatarUrl;
  String? _avatarAssetId;
  XFile? _selectedAvatar;
  bool _uploadingPhoto = false;
  final CancelToken _uploadCancelToken = CancelToken();
  bool _loading = false;
  bool _seeded = false;
  bool _completed = false;
  final _exitGuard = DraftExitGuard();
  String? _initialSnapshot;
  String get _snapshot => [_displayName.text, _bio.text, _city.text, _year.text,
      _visibility, _country, _avatarAssetId ?? '', _instagram.text,
      _tiktok.text, _youtube.text].join('\u0000');
  bool get _dirty => !_completed && _seeded &&
      (_snapshot != _initialSnapshot || _selectedAvatar != null);
  void _leave() => _exitGuard.leave(context, dirty: _dirty,
      busy: _loading || _uploadingPhoto,
      refresh: () => setState(() {}), pop: () => context.pop());

  void _onDraftChanged() { if (mounted && _seeded) setState(() {}); }

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController();
    _bio = TextEditingController();
    _city = TextEditingController();
    _year = TextEditingController();
    _instagram = TextEditingController();
    _tiktok = TextEditingController();
    _youtube = TextEditingController();
    for (final controller in [_displayName, _bio, _city, _year, _instagram, _tiktok, _youtube]) {
      controller.addListener(_onDraftChanged);
    }
    _media = widget.media ?? MediaUploadService();
  }

  @override
  void dispose() {
    _uploadCancelToken.cancel();
    for (final controller in [_displayName, _bio, _city, _year, _instagram, _tiktok, _youtube]) {
      controller.removeListener(_onDraftChanged);
    }
    _displayName.dispose();
    _bio.dispose();
    _city.dispose();
    _year.dispose();
    _instagram.dispose();
    _tiktok.dispose();
    _youtube.dispose();
    super.dispose();
  }

  void _seed(PassportModel passport) {
    if (_seeded) return;
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
    _instagram.text = passport.identity.instagramUrl ?? '';
    _tiktok.text = passport.identity.tiktokUrl ?? '';
    _youtube.text = passport.identity.youtubeUrl ?? '';
    _initialSnapshot = _snapshot;
    _seeded = true;
  }

  Future<void> _changePhoto() async {
    final source = _selectedAvatar == null
        ? await showGarraSheet<ImageSource>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'Cambiar foto',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
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
                  const SizedBox(height: 8),
                ],
              ),
            ),
          )
        : null;
    if (_selectedAvatar == null && source == null) return;
    if (!mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final file =
          _selectedAvatar ??
          (source == ImageSource.camera
              ? await _media.pickCamera(maxSide: 1024)
              : await _media.pickImage(maxSide: 1024));
      if (!mounted) return;
      if (file == null) {
        setState(() => _uploadingPhoto = false);
        return;
      }
      if (!allowNetworkAction(context)) {
        setState(() {
          _selectedAvatar = file;
          _uploadingPhoto = false;
        });
        return;
      }
      setState(() => _selectedAvatar = file);
      final draft = await _media.uploadAvatar(file, canStartRemote: () => mounted && allowNetworkAction(context), cancelToken: _uploadCancelToken);
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
        _selectedAvatar = null;
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
    if (!allowNetworkAction(context)) return;
    setState(() => _loading = true);
    try {
      final yearText = _year.text.trim();
      await ref
          .read(passportServiceProvider)
          .updateMyProfile(
            ProfileUpdateRequest(
              displayName: _displayName.text.trim(),
              bio: _bio.text.trim(),
              city: _city.text.trim(),
              countryCode: _country,
              supporterSinceYear: yearText.isEmpty
                  ? null
                  : int.tryParse(yearText),
              updateSupporterSinceYear: true,
              profileVisibility: _visibility,
              avatarMediaAssetId: _avatarAssetId,
              instagramUrl: _instagram.text.trim(),
              tiktokUrl: _tiktok.text.trim(),
              youtubeUrl: _youtube.text.trim(),
              updateSocialLinks: true,
            ),
          );
      ref.invalidate(myPassportProvider);
      if (!mounted) return;
      _completed = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      context.pop();
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message != null && message.startsWith('Enlace de ')
            ? message : 'No se pudo guardar el perfil'),
      ));
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

    return PopScope(
      canPop: _exitGuard.canPop(dirty: _dirty, busy: _loading || _uploadingPhoto),
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _leave(); },
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(leading: BackButton(onPressed: _leave), title: const Text('Editar perfil')),
      bottomNavigationBar: passportAsync.maybeWhen(
        data: (_) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg, GarraSpacing.sm, GarraSpacing.lg, GarraSpacing.sm),
            child: IntrinsicHeight(child: GarraFormActionBar(
              label: 'Guardar cambios',
              loading: _loading,
              onPressed: _submit,
            )),
          ),
        ),
        orElse: () => null,
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
              scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
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
                          _uploadingPhoto
                              ? 'Subiendo foto…'
                              : _selectedAvatar != null
                              ? 'Subir foto seleccionada'
                              : 'Cambiar foto',
                        ),
                      ),
                    ],
                  ),
                ),
                GarraFormSection(
                  title: 'IDENTIDAD',
                  children: [
                    GarraTextField(
                      label: 'Nombre visible',
                      controller: _displayName,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.length < 2) return 'Mínimo 2 caracteres';
                        if (v.length > 120) return 'Máximo 120 caracteres';
                        return null;
                      },
                    ),
                    GarraTextArea(
                      label: 'Bio',
                      controller: _bio,
                      maxLength: 280,
                      minLines: 3,
                    ),
                  ],
                ),
                GarraFormSection(
                  title: 'UBICACIÓN',
                  children: [
                    GarraTextField(
                      label: 'Ciudad',
                      controller: _city,
                      validator: (value) {
                        if ((value ?? '').length > 80) {
                          return 'Máximo 80 caracteres';
                        }
                        return null;
                      },
                    ),
                    GarraSelectField<String>(
                      label: 'País',
                      value: _country,
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
                  ],
                ),
                GarraFormSection(
                  title: 'HINCHA',
                  children: [
                    GarraTextField(
                      label: 'Crema desde',
                      controller: _year,
                      fieldKey: const Key('profile-supporter-year'),
                      keyboardType: TextInputType.number,
                      helper: 'Año en que empezaste a alentar. Ejemplo: 2012',
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
                  ],
                ),
                GarraFormSection(
                  title: 'PRIVACIDAD',
                  children: [
                    GarraSelectField<String>(
                      label: 'Visibilidad',
                      value: _visibility,
                      items: const [
                        DropdownMenuItem(
                          value: 'PUBLIC',
                          child: Text('Público'),
                        ),
                        DropdownMenuItem(
                          value: 'MEMBERS_ONLY',
                          child: Text('Solo miembros'),
                        ),
                        DropdownMenuItem(
                          value: 'PRIVATE',
                          child: Text('Privado'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _visibility = value);
                      },
                    ),
                  ],
                ),
                GarraFormSection(
                  title: 'MIS REDES SOCIALES',
                  children: [
                    GarraTextField(label: 'Instagram', controller: _instagram,
                      helper: '@usuario o enlace de perfil'),
                    GarraTextField(label: 'TikTok', controller: _tiktok,
                      helper: '@usuario o enlace de perfil'),
                    GarraTextField(label: 'YouTube', controller: _youtube,
                      helper: '@canal o enlace de canal'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ));
  }
}
