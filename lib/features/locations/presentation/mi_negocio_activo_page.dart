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
import '../data/crema_business_engagement_service.dart';
import '../data/crema_business_offer_models.dart';
import 'create_business_offer_page.dart';
import '../../../core/widgets/garra_card.dart';
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
    this.engagement,
  });

  final String applicationId;
  final CremaBusinessApplication? initial;
  final CremaBusinessApplicationService? service;
  final MediaUploadService? media;
  final CremaBusinessEngagementService? engagement;

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

  CremaBusinessEngagementService? _engagementInstance;
  CremaBusinessEngagementService get _engagement =>
      _engagementInstance ??=
          widget.engagement ?? CremaBusinessEngagementService();
  List<CremaBusinessOffer> _offers = const [];
  bool _offersLoading = false;
  String? _offersError;

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
      if (match != null && match.isApprovedBusiness) {
        await _loadOffers(match.cremaPointId!);
      }
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


  Future<void> _loadOffers(String pointId) async {
    setState(() {
      _offersLoading = true;
      _offersError = null;
    });
    try {
      final offers = await _engagement
          .listOwnedOffers(pointId)
          .timeout(const Duration(seconds: 4));
      if (!mounted) return;
      offers.sort(_offerSort);
      setState(() {
        _offers = offers;
        _offersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offersLoading = false;
        _offersError = 'No pudimos cargar tus ofertas';
      });
    }
  }

  int _offerSort(CremaBusinessOffer a, CremaBusinessOffer b) {
    int rank(CremaBusinessOffer o) {
      if (o.isActive && !o.vigenciaTerminada) return 0;
      if (o.isDraft) return 1;
      if (o.isActive && o.vigenciaTerminada) return 2;
      if (o.status == CremaBusinessOfferStatus.expired) return 3;
      return 4;
    }

    final c = rank(a).compareTo(rank(b));
    if (c != 0) return c;
    final aDate = a.publishedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.publishedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  }

  Future<void> _openCreate({CremaBusinessOffer? draft}) async {
    final item = _item;
    if (item == null || !item.isApprovedBusiness) return;
    final result = await Navigator.of(context).push<CremaBusinessOffer>(
      MaterialPageRoute(
        builder: (_) => CreateBusinessOfferPage(
          pointId: item.cremaPointId!,
          businessName: item.businessName,
          engagement: _engagement,
          media: _media,
          initial: draft,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      await _loadOffers(item.cremaPointId!);
    }
  }

  Future<void> _publish(CremaBusinessOffer offer) async {
    if (_saving || !allowNetworkAction(context)) return;
    setState(() => _saving = true);
    try {
      await _engagement.publishOffer(offer.id);
      if (!mounted) return;
      _snack('Oferta publicada');
      await _loadOffers(offer.cremaPointId);
    } catch (_) {
      if (mounted) _snack('No pudimos publicar la oferta.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel(CremaBusinessOffer offer) async {
    if (_saving || !allowNetworkAction(context)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar oferta'),
        content: const Text(
          'La oferta dejará de mostrarse a la hinchada. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar oferta'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _engagement.cancelOffer(offer.id);
      if (!mounted) return;
      _snack('Oferta cancelada');
      await _loadOffers(offer.cremaPointId);
    } catch (_) {
      if (mounted) _snack('No pudimos cancelar la oferta.');
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

        Text('OFERTAS Y PROMOCIONES', style: text.labelLarge?.copyWith(
          color: colors.brandPrestige,
          fontWeight: FontWeight.w800,
        ), key: const ValueKey('owner_offers_section')),
        const SizedBox(height: GarraSpacing.sm),
        if (_offersLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: GarraSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_offersError != null)
          GarraErrorState(
            title: 'No pudimos cargar ofertas',
            message: _offersError!,
            onRetry: () => _loadOffers(pointId),
          )
        else if (_offers.isEmpty)
          GarraEmptyState(
            title: 'Aún no tienes ofertas',
            message:
                'Publica una promoción para que la hinchada la vea en Ofertas crema.',
            hint:
                '¿Cómo funciona?\n1) Crea el título y el beneficio\n2) Elige vigencia e imagen (opcional)\n3) Publica cuando esté lista',
            actionLabel: 'Crear mi primera oferta',
            onAction: _saving ? null : () => _openCreate(),
          )
        else ...[
          ..._offers.map((o) => _OwnerOfferCard(
                offer: o,
                busy: _saving,
                onPublish: o.isDraft ? () => _publish(o) : null,
                onEdit: o.isDraft ? () => _openCreate(draft: o) : null,
                onCancel: (!o.isCancelled && o.status != CremaBusinessOfferStatus.expired)
                    ? () => _cancel(o)
                    : null,
              )),
          const SizedBox(height: GarraSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('owner_offers_create'),
            onPressed: _saving ? null : () => _openCreate(),
            icon: const Icon(Icons.add),
            label: const Text('Crear oferta'),
          ),
        ],
        const SizedBox(height: GarraSpacing.xl),
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


class _OwnerOfferCard extends StatelessWidget {
  const _OwnerOfferCard({
    required this.offer,
    required this.busy,
    this.onPublish,
    this.onEdit,
    this.onCancel,
  });

  final CremaBusinessOffer offer;
  final bool busy;
  final VoidCallback? onPublish;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.garraColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: GarraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((offer.imageUrl ?? '').isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(GarraRadius.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: GarraCachedNetworkImage(
                    imageUrl: offer.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: GarraSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(offer.title, style: text.titleMedium),
                ),
                Chip(
                  label: Text(offer.statusChipLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              offer.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium,
            ),
            if (offer.startsAt != null || offer.endsAt != null) ...[
              const SizedBox(height: 6),
              Text(
                _vigencia(offer),
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (onEdit != null)
                  TextButton(
                    onPressed: busy ? null : onEdit,
                    child: const Text('Editar'),
                  ),
                if (onPublish != null)
                  FilledButton(
                    onPressed: busy ? null : onPublish,
                    child: const Text('Publicar'),
                  ),
                if (onCancel != null)
                  TextButton(
                    onPressed: busy ? null : onCancel,
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _vigencia(CremaBusinessOffer o) {
    String fmt(DateTime? d) {
      if (d == null) return '—';
      final l = d.toLocal();
      final dd = l.day.toString().padLeft(2, '0');
      final mm = l.month.toString().padLeft(2, '0');
      return '$dd/$mm/${l.year}';
    }

    return 'Vigencia: ${fmt(o.startsAt)} → ${fmt(o.endsAt)}';
  }
}

