import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_cached_network_image.dart';
import '../../../core/widgets/garra_single_photo_field.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/business_map_links.dart';
import '../data/business_social_links.dart';
import '../data/crema_business_application_service.dart';
import 'mi_negocio_crema_page.dart';

/// SONIC_01: the owner's page for an approved business. Data always comes
/// from the owner-only `/business-applications/me` (ownership enforced by the
/// backend); it shows the public presence, links to the public page and the
/// map, and lets the owner manage the single cover photo. No other edit
/// actions: the backend does not support editing a verified business.
class MiNegocioActivoPage extends StatefulWidget {
  const MiNegocioActivoPage({
    super.key,
    required this.applicationId,
    this.initial,
    this.service,
    this.media,
  });

  final String applicationId;
  final CremaBusinessApplication? initial;
  final CremaBusinessApplicationService? service;
  final MediaUploadService? media;

  @override
  State<MiNegocioActivoPage> createState() => _MiNegocioActivoPageState();
}

class _MiNegocioActivoPageState extends State<MiNegocioActivoPage> {
  late final CremaBusinessApplicationService _service =
      widget.service ?? CremaBusinessApplicationService();
  MediaUploadService? _mediaInstance;
  MediaUploadService get _media =>
      _mediaInstance ??= widget.media ?? MediaUploadService();

  CremaBusinessApplication? _item;
  bool _loading = true;
  bool _failed = false;
  XFile? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.id == widget.applicationId) {
      _item = initial;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _item == null;
      _failed = false;
    });
    try {
      final mine = await _service.listMine();
      if (!mounted) return;
      CremaBusinessApplication? match;
      for (final item in mine) {
        if (item.id == widget.applicationId) match = item;
      }
      setState(() {
        _item = match;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _pick() async {
    final file = await _media.pickImage();
    if (file == null || !mounted) return;
    setState(() => _photo = file);
  }

  Future<void> _savePhoto() async {
    final item = _item;
    final photo = _photo;
    if (item == null || photo == null || !allowNetworkAction(context)) return;
    setState(() => _saving = true);
    try {
      final assetId = await uploadSinglePhoto(
        _media,
        photo,
        MediaUploadPurpose.businessMedia,
        canStartRemote: () => mounted && allowNetworkAction(context),
      );
      if (!mounted) return;
      final updated = await _service.updateCover(item.id, assetId);
      if (!mounted) return;
      setState(() {
        _item = updated;
        _photo = null;
      });
      _snack('Foto del negocio actualizada');
    } on SinglePhotoUploadException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('No pudimos guardar la foto. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_photo != null) {
      setState(() => _photo = null);
      return;
    }
    final item = _item;
    if (item == null || item.coverImageUrl == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar foto'),
        content: const Text(
          'Tu negocio se mostrará sin foto en Negocios Crema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !allowNetworkAction(context)) return;
    setState(() => _saving = true);
    try {
      final updated = await _service.removeCover(item.id);
      if (!mounted) return;
      setState(() => _item = updated);
      _snack('Quitamos la foto del negocio');
    } catch (_) {
      if (mounted) _snack('No pudimos quitar la foto. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(title: Text(item?.businessName ?? 'Mi negocio')),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: context.garraColors.brandPrestige,
              ),
            )
          : _failed && item == null
          ? GarraErrorState(
              title: 'No pudimos cargar tu negocio',
              onRetry: _load,
            )
          : item == null || !item.isApprovedBusiness
          ? const GarraEmptyState(
              title: 'Negocio no disponible',
              message:
                  'Este negocio no aparece entre tus negocios activos. Revisa “Mis negocios”.',
            )
          : RefreshIndicator(onRefresh: _load, child: _content(item)),
    );
  }

  Widget _content(CremaBusinessApplication item) {
    final colors = context.garraColors;
    final text = Theme.of(context).textTheme;
    final pointId = item.cremaPointId!;
    final socials = <(BusinessSocialNetwork, String?)>[
      (BusinessSocialNetwork.instagram, item.instagram),
      (BusinessSocialNetwork.facebook, item.facebook),
      (BusinessSocialNetwork.tiktok, item.tiktok),
    ].where((e) => businessSocialUri(e.$1, e.$2) != null).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        GarraSpacing.section,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: (item.coverImageUrl ?? '').isEmpty
                ? ColoredBox(
                    key: const ValueKey('business_cover_fallback'),
                    color: colors.surfaceMuted,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 44,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tu negocio aún no tiene foto',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : GarraCachedNetworkImage(
                    imageUrl: item.coverImageUrl!,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: GarraSpacing.lg),
        Text(item.businessName, style: text.headlineSmall),
        const SizedBox(height: GarraSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: BusinessOwnerStatusChip(item: item),
        ),
        if (!item.isPubliclyVisible) ...[
          const SizedBox(height: GarraSpacing.sm),
          Text(
            'Garra pausó temporalmente su aparición en el mapa y el directorio.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
        if (item.category.isNotEmpty) ...[
          const SizedBox(height: GarraSpacing.md),
          Text(
            item.category,
            style: TextStyle(
              color: colors.brandPrestige,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if ((item.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: GarraSpacing.sm),
          Text(item.description!.trim()),
        ],
        const SizedBox(height: GarraSpacing.md),
        _Line(icon: Icons.place_outlined, text: publicBusinessArea(item.address)),
        if ((item.phone ?? '').trim().isNotEmpty)
          _Line(icon: Icons.call_outlined, text: item.phone!.trim()),
        if ((item.whatsapp ?? '').trim().isNotEmpty)
          _Line(icon: Icons.chat_outlined, text: 'WhatsApp · ${item.whatsapp!.trim()}'),
        if (socials.isNotEmpty)
          _Line(
            icon: Icons.public,
            text: socials.map((e) => socialNetworkLabel(e.$1)).join(' · '),
          ),
        const SizedBox(height: GarraSpacing.lg),
        if (item.isPubliclyVisible) ...[
          FilledButton.icon(
            onPressed: () => context.push('/negocios/$pointId'),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Ver ficha pública'),
          ),
          const SizedBox(height: GarraSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => context.push('/negocios/mapa?pointId=$pointId'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ver en el mapa'),
          ),
          const SizedBox(height: GarraSpacing.xl),
        ],
        Text('FOTO DEL NEGOCIO', style: text.labelLarge?.copyWith(
          color: colors.brandPrestige,
          fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: GarraSpacing.sm),
        GarraSinglePhotoField(
          file: _photo,
          currentUrl: item.coverImageUrl,
          enabled: !_saving,
          label: 'Foto principal',
          helper:
              'Una foto real de tu local o tu marca. Se verá en tu ficha pública.',
          onPick: _pick,
          onRemove: _removePhoto,
        ),
        if (_photo != null)
          FilledButton(
            key: const ValueKey('business_cover_save'),
            onPressed: _saving ? null : _savePhoto,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar foto'),
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.garraColors.textSecondary),
        const SizedBox(width: GarraSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
