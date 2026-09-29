import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_single_photo_field.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/clan_models.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../data/clan_admin_permissions.dart';
import 'clan_bans_page.dart';
import 'clan_members_admin_page.dart';
import 'create_community_page.dart'
    show
        CommunityOptionTile,
        communityJoinOptions,
        communityPostsPrivacyNote,
        communityVisibilityOptions;
import 'providers/clans_provider.dart';

class ClanManagePage extends ConsumerStatefulWidget {
  const ClanManagePage({super.key, required this.slug, this.media});

  final String slug;

  /// Injectable for tests; defaults to the real signed-upload pipeline.
  final MediaUploadService? media;

  @override
  ConsumerState<ClanManagePage> createState() => _ClanManagePageState();
}

class _ClanManagePageState extends ConsumerState<ClanManagePage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  String _visibility = 'PUBLIC';
  String _joinPolicy = 'OPEN';
  bool _initialized = false;
  bool _saving = false;
  late final MediaUploadService _media = widget.media ?? MediaUploadService();
  XFile? _avatar;
  XFile? _cover;
  bool _removeAvatar = false;
  bool _removeCover = false;

  Future<void> _pickAvatar() async {
    final file = await _media.pickImage(maxSide: 1024);
    if (file == null || !mounted) return;
    setState(() {
      _avatar = file;
      _removeAvatar = false;
    });
  }

  Future<void> _pickCover() async {
    final file = await _media.pickImage();
    if (file == null || !mounted) return;
    setState(() {
      _cover = file;
      _removeCover = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _hydrate(ClanModel clan) {
    if (_initialized) return;
    _nameController.text = clan.name;
    _descriptionController.text = clan.description ?? '';
    _cityController.text = clan.city ?? '';
    _countryController.text = clan.countryCode ?? '';
    _visibility = clan.visibility;
    _joinPolicy = clan.joinPolicy;
    _initialized = true;
  }

  Future<void> _save() async {
    if (!allowNetworkAction(context)) return;
    setState(() => _saving = true);
    try {
      final avatar = _avatar;
      final cover = _cover;
      final logoId = avatar == null
          ? null
          : await uploadSinglePhoto(
              _media,
              avatar,
              MediaUploadPurpose.communityPost,
            );
      if (!mounted || !allowNetworkAction(context)) return;
      final bannerId = cover == null
          ? null
          : await uploadSinglePhoto(
              _media,
              cover,
              MediaUploadPurpose.communityPost,
            );
      if (!mounted || !allowNetworkAction(context)) return;
      await ref
          .read(clanServiceProvider)
          .updateClan(
            widget.slug,
            UpdateClanRequest(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              city: _cityController.text.trim(),
              countryCode: _countryController.text.trim().toUpperCase(),
              visibility: _visibility,
              joinPolicy: _joinPolicy,
              logoMediaAssetId: logoId,
              bannerMediaAssetId: bannerId,
              clearLogo: _removeAvatar && logoId == null,
              clearBanner: _removeCover && bannerId == null,
            ),
          );
      ref.invalidate(clanDetailProvider(widget.slug));
      ref.invalidate(myClansProvider);
      if (mounted) {
        setState(() {
          _avatar = null;
          _cover = null;
          _removeAvatar = false;
          _removeCover = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comunidad actualizada')));
      }
    } on SinglePhotoUploadException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos guardar los cambios. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(clanDetailProvider(widget.slug));
    ref.invalidate(clanJoinRequestsProvider(widget.slug));
    ref.invalidate(clanMembersPreviewProvider(widget.slug));
    await Future.wait([
      ref.read(clanDetailProvider(widget.slug).future),
      ref.read(clanJoinRequestsProvider(widget.slug).future),
      ref.read(clanMembersPreviewProvider(widget.slug).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final clanAsync = ref.watch(clanDetailProvider(widget.slug));
    final requestsAsync = ref.watch(clanJoinRequestsProvider(widget.slug));
    final membersAsync = ref.watch(clanMembersPreviewProvider(widget.slug));

    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(title: const Text('Administrar comunidad')),
      body: clanAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: context.garraColors.brandPrestige,
          ),
        ),
        error: (_, __) => GarraErrorState(onRetry: _refresh),
        data: (clan) {
          _hydrate(clan);
          return RefreshIndicator(
            color: context.garraColors.brandPrestige,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.section,
              ),
              children: [
                const GarraSectionHeader(
                  title: 'Perfil de la comunidad',
                  subtitle: 'Nombre, imagen y acceso',
                ),
                const SizedBox(height: GarraSpacing.md),
                GarraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GarraSinglePhotoField(
                        key: const ValueKey('manage_avatar_field'),
                        file: _avatar,
                        currentUrl: _removeAvatar ? null : clan.logoUrl,
                        enabled: !_saving,
                        label: 'Avatar',
                        helper: 'Una foto cuadrada: escudo, bandera o logo.',
                        addLabel: 'Agregar avatar',
                        aspectRatio: 1,
                        previewMaxWidth: 140,
                        onPick: _pickAvatar,
                        onRemove: () => setState(() {
                          _avatar = null;
                          _removeAvatar = true;
                        }),
                      ),
                      GarraSinglePhotoField(
                        key: const ValueKey('manage_cover_field'),
                        file: _cover,
                        currentUrl: _removeCover ? null : clan.bannerUrl,
                        enabled: !_saving,
                        label: 'Portada',
                        helper: 'Una foto horizontal para la cabecera.',
                        addLabel: 'Agregar portada',
                        onPick: _pickCover,
                        onRemove: () => setState(() {
                          _cover = null;
                          _removeCover = true;
                        }),
                      ),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                        ),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      TextField(
                        controller: _countryController,
                        decoration: const InputDecoration(labelText: 'País'),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      Text(
                        'Privacidad',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      for (final option in communityVisibilityOptions)
                        CommunityOptionTile(
                          key: ValueKey('manage_visibility_${option.value}'),
                          selected: _visibility == option.value,
                          title: option.title,
                          subtitle: option.subtitle,
                          onTap: () =>
                              setState(() => _visibility = option.value),
                        ),
                      Text(
                        communityPostsPrivacyNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      Text(
                        'Ingreso',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      for (final option in communityJoinOptions)
                        CommunityOptionTile(
                          key: ValueKey('manage_join_${option.value}'),
                          selected: _joinPolicy == option.value,
                          title: option.title,
                          subtitle: option.subtitle,
                          onTap: () =>
                              setState(() => _joinPolicy = option.value),
                        ),
                      const SizedBox(height: GarraSpacing.lg),
                      GarraPrimaryButton(
                        label: 'Guardar',
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GarraSpacing.xxl),
                const GarraSectionHeader(
                  title: 'Solicitudes pendientes',
                  subtitle: 'Aprueba o rechaza ingresos',
                ),
                const SizedBox(height: GarraSpacing.md),
                requestsAsync.when(
                  loading: () => const GarraSkeleton(height: 80),
                  error: (_, __) => GarraErrorState(onRetry: _refresh),
                  data: (requests) {
                    final pending = requests
                        .where((r) => r.status.toUpperCase() == 'PENDING')
                        .toList();
                    if (pending.isEmpty) {
                      return GarraCard(
                        child: Text(
                          'No hay solicitudes pendientes.',
                          style: TextStyle(
                            color: context.garraColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: pending
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: GarraSpacing.sm,
                              ),
                              child: _RequestCard(
                                request: r,
                                onApprove: () async {
                                  await ref
                                      .read(clanServiceProvider)
                                      .approveJoinRequest(widget.slug, r.id);
                                  ref.invalidate(
                                    clanJoinRequestsProvider(widget.slug),
                                  );
                                  ref.invalidate(
                                    clanDetailProvider(widget.slug),
                                  );
                                  ref.invalidate(
                                    clanMembersPreviewProvider(widget.slug),
                                  );
                                },
                                onReject: () async {
                                  await ref
                                      .read(clanServiceProvider)
                                      .rejectJoinRequest(widget.slug, r.id);
                                  ref.invalidate(
                                    clanJoinRequestsProvider(widget.slug),
                                  );
                                },
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: GarraSpacing.xxl),
                const GarraSectionHeader(
                  title: 'Miembros',
                  subtitle: 'Comunidad del clan',
                ),
                const SizedBox(height: GarraSpacing.md),
                _ManageEntryTile(
                  key: const ValueKey('manage_members_entry'),
                  icon: Icons.groups_rounded,
                  title: 'Gestionar miembros',
                  subtitle: 'Roles, expulsiones y bloqueos',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ClanMembersAdminPage(slug: widget.slug),
                    ),
                  ),
                ),
                if (ClanAdminPermissions.canViewBans(clan.myMembership?.role))
                  _ManageEntryTile(
                    key: const ValueKey('manage_bans_entry'),
                    icon: Icons.block_rounded,
                    title: 'Personas bloqueadas',
                    subtitle: 'Revisa y quita bloqueos',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ClanBansPage(slug: widget.slug),
                      ),
                    ),
                  ),
                const SizedBox(height: GarraSpacing.sm),
                membersAsync.when(
                  loading: () => const GarraSkeleton(height: 80),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (members) {
                    if (members.isEmpty) {
                      return GarraCard(
                        child: Text(
                          'Sin miembros para mostrar.',
                          style: TextStyle(
                            color: context.garraColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: members
                          .map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: GarraSpacing.sm,
                              ),
                              child: GarraCard(
                                child: Row(
                                  children: [
                                    GarraAvatar(
                                      displayName: m.displayName,
                                      avatarUrl: m.avatarUrl,
                                      size: 40,
                                    ),
                                    const SizedBox(width: GarraSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.displayName,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          Text(
                                            '@${m.username}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      ClanRoleLabels.label(m.role),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: context
                                                .garraColors
                                                .brandPrestige,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ManageEntryTile extends StatelessWidget {
  const _ManageEntryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
      child: GarraCard(
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, color: colors.brandPrestige),
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
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final ClanJoinRequestModel request;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GarraAvatar(
                displayName: request.displayName,
                avatarUrl: request.avatarUrl,
                size: 40,
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '@${request.username}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message != null &&
              request.message!.trim().isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              request.message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: GarraSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onReject(),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => onApprove(),
                  child: const Text('Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
