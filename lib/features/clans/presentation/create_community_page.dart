import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/utils/country_labels.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_single_photo_field.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/clan_models.dart';
import 'providers/clans_provider.dart';

/// One selectable community setting (privacy or join policy).
typedef CommunityOption = ({String value, String title, String subtitle});

/// Copy matches what the backend enforces (ClanQueryService / GlobalSearch):
/// PUBLIC and MEMBERS_ONLY are discoverable, PRIVATE is not; the member list
/// is public only for PUBLIC. Posts are always members-only.
const List<CommunityOption> communityVisibilityOptions = [
  (
    value: 'PUBLIC',
    title: 'Pública',
    subtitle:
        'Aparece en Descubrir y en búsquedas. Cualquiera puede ver la comunidad y sus miembros.',
  ),
  (
    value: 'MEMBERS_ONLY',
    title: 'Solo miembros',
    subtitle:
        'Aparece en Descubrir, pero solo los miembros ven la lista de miembros.',
  ),
  (
    value: 'PRIVATE',
    title: 'Privada',
    subtitle:
        'No aparece en Descubrir ni en búsquedas. Solo miembros e invitados pueden verla.',
  ),
];

const String communityPostsPrivacyNote =
    'Las publicaciones de la comunidad siempre son solo para miembros.';

/// Join policy copy (backend: OPEN joins directly, REQUEST is approved by the
/// owner or admins, INVITE_ONLY rejects direct joins).
const List<CommunityOption> communityJoinOptions = [
  (
    value: 'OPEN',
    title: 'Abierto',
    subtitle: 'Los hinchas pueden unirse directamente.',
  ),
  (
    value: 'REQUEST',
    title: 'Con aprobación',
    subtitle: 'El líder o los administradores aprueban las solicitudes.',
  ),
  (
    value: 'INVITE_ONLY',
    title: 'Solo invitación',
    subtitle: 'Solo se puede ingresar mediante una invitación.',
  ),
];

/// Create a community (backend: clan). The backend generates the slug from
/// the name, so there is no "Identificador" field.
class CreateCommunityPage extends ConsumerStatefulWidget {
  const CreateCommunityPage({super.key, this.media});

  /// Injectable for tests; defaults to the real signed-upload pipeline.
  final MediaUploadService? media;

  @override
  ConsumerState<CreateCommunityPage> createState() =>
      _CreateCommunityPageState();
}

class _CreateCommunityPageState extends ConsumerState<CreateCommunityPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  late final MediaUploadService _media = widget.media ?? MediaUploadService();

  String _country = 'PE';
  String _visibility = 'PUBLIC';
  String _joinPolicy = 'OPEN';
  bool _submitting = false;
  XFile? _avatar;
  XFile? _cover;
  // Uploaded asset ids are reused on retry so a failed create does not
  // upload the same photo twice.
  String? _avatarAssetId;
  String? _coverAssetId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _media.pickImage(maxSide: 1024);
    if (file == null || !mounted) return;
    setState(() {
      _avatar = file;
      _avatarAssetId = null;
    });
  }

  Future<void> _pickCover() async {
    final file = await _media.pickImage();
    if (file == null || !mounted) return;
    setState(() {
      _cover = file;
      _coverAssetId = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!allowNetworkAction(context)) return;
    setState(() => _submitting = true);
    try {
      final avatar = _avatar;
      if (avatar != null) {
        _avatarAssetId ??= await uploadSinglePhoto(
          _media,
          avatar,
          MediaUploadPurpose.communityPost,
        );
      }
      final cover = _cover;
      if (cover != null) {
        if (!mounted || !allowNetworkAction(context)) return;
        _coverAssetId ??= await uploadSinglePhoto(
          _media,
          cover,
          MediaUploadPurpose.communityPost,
        );
      }
      final description = _descCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      if (!mounted || !allowNetworkAction(context)) return;
      final clan = await ref
          .read(clanServiceProvider)
          .createClan(
            CreateClanRequest(
              name: _nameCtrl.text.trim(),
              description: description.isEmpty ? null : description,
              city: city.isEmpty ? null : city,
              countryCode: _country,
              visibility: _visibility,
              joinPolicy: _joinPolicy,
              logoMediaAssetId: avatar == null ? null : _avatarAssetId,
              bannerMediaAssetId: cover == null ? null : _coverAssetId,
            ),
          );
      ref.invalidate(myClansProvider);
      ref.invalidate(clanDiscoveryProvider(const ClanDiscoveryQuery()));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comunidad creada')));
      context.go('/clans/${clan.slug}');
    } on SinglePhotoUploadException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos crear la comunidad. Revisa los datos.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Crear comunidad')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(GarraSpacing.lg),
          children: [
            Text(
              'Dale identidad a tu gente',
              style: textTheme.titleLarge?.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: GarraSpacing.xs),
            Text(
              'Un avatar y una portada hacen que tu comunidad se reconozca en la tribuna.',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: GarraSpacing.lg),
            GarraSinglePhotoField(
              key: const ValueKey('community_avatar_field'),
              file: _avatar,
              enabled: !_submitting,
              label: 'Avatar (opcional)',
              helper: 'Una foto cuadrada: escudo, bandera o logo.',
              addLabel: 'Agregar avatar',
              aspectRatio: 1,
              previewMaxWidth: 140,
              onPick: _pickAvatar,
              onRemove: () => setState(() {
                _avatar = null;
                _avatarAssetId = null;
              }),
            ),
            GarraSinglePhotoField(
              key: const ValueKey('community_cover_field'),
              file: _cover,
              enabled: !_submitting,
              label: 'Portada (opcional)',
              helper: 'Una foto horizontal para la cabecera de la comunidad.',
              addLabel: 'Agregar portada',
              onPick: _pickCover,
              onRemove: () => setState(() {
                _cover = null;
                _coverAssetId = null;
              }),
            ),
            const SizedBox(height: GarraSpacing.sm),
            GarraFormSection(
              title: 'COMUNIDAD',
              children: [
                GarraTextField(
                  label: 'Nombre',
                  controller: _nameCtrl,
                  fieldKey: const ValueKey('community_name_field'),
                  maxLength: 120,
                  helper: 'El enlace de la comunidad se crea automáticamente.',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().length < 2) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                GarraTextArea(
                  label: 'Descripción',
                  controller: _descCtrl,
                  minLines: 3,
                  maxLength: 1000,
                ),
                GarraTextField(
                  label: 'Ciudad',
                  controller: _cityCtrl,
                  maxLength: 80,
                  helper: 'Lima, Arequipa.',
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
            const SizedBox(height: GarraSpacing.xxl),
            Text(
              'Privacidad',
              style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: GarraSpacing.sm),
            for (final option in communityVisibilityOptions)
              CommunityOptionTile(
                key: ValueKey('community_visibility_${option.value}'),
                selected: _visibility == option.value,
                title: option.title,
                subtitle: option.subtitle,
                onTap: () => setState(() => _visibility = option.value),
              ),
            Text(
              communityPostsPrivacyNote,
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: GarraSpacing.xxl),
            Text(
              'Ingreso',
              style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: GarraSpacing.sm),
            for (final option in communityJoinOptions)
              CommunityOptionTile(
                key: ValueKey('community_join_${option.value}'),
                selected: _joinPolicy == option.value,
                title: option.title,
                subtitle: option.subtitle,
                onTap: () => setState(() => _joinPolicy = option.value),
              ),
            const SizedBox(height: GarraSpacing.xxl),
            GarraPrimaryButton(
              label: _submitting ? 'Creando.' : 'Crear comunidad',
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: GarraSpacing.section),
          ],
        ),
      ),
    );
  }
}

/// Selectable privacy / join tile. Noche keeps the original garnet-selected
/// look; Crema uses light surfaces with a garnet outline.
class CommunityOptionTile extends StatelessWidget {
  const CommunityOptionTile({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? colors.brandPrestige : colors.brandPrimary;
    final background = selected
        ? (isDark ? const Color(GarraColors.garnetDeep) : colors.surfaceRaised)
        : colors.surface;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          side: isDark
              ? BorderSide.none
              : BorderSide(color: selected ? accent : colors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GarraRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(GarraSpacing.md),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: accent,
                ),
                const SizedBox(width: GarraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
