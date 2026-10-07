import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/navigation/draft_exit_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_media_service.dart';
import '../data/marketplace_models.dart';
import '../data/marketplace_service.dart';
import 'providers/marketplace_provider.dart';

class SellerListingFormPage extends ConsumerStatefulWidget {
  const SellerListingFormPage({super.key, this.slug, this.storeId});

  final String? slug;

  /// MARKETPLACE_V2_A1: business the new listing belongs to. Without it (no
  /// store context) the form auto-selects the only business or asks the
  /// seller to choose among 2-3; a listing is never created without a store.
  final String? storeId;

  bool get isEditing => slug != null && slug!.isNotEmpty;

  @override
  ConsumerState<SellerListingFormPage> createState() =>
      _SellerListingFormPageState();
}

class _SellerListingFormPageState extends ConsumerState<SellerListingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _categorySlug;
  bool _priceOnRequest = false;
  bool _loading = false;
  bool _hydrated = false;
  String? _listingId;

  /// DEMO_HARDENING_03: last known server state of the listing (edit mode or
  /// after the first save) so the CTAs match the backend lifecycle.
  MarketplaceListing? _loaded;
  String? _pickedStoreId;
  List<MarketplaceStore> _eligibleStores = const [];
  final List<ListingImageDraft> _images = [];
  final CancelToken _uploadCancelToken = CancelToken();
  final _exitGuard = DraftExitGuard();
  bool _completed = false;
  String? _initialSnapshot;
  String get _snapshot => [
    _titleController.text, _descriptionController.text, _priceController.text,
    _categorySlug ?? '', _pickedStoreId ?? '', '$_priceOnRequest',
    ..._images.map((image) => image.localId),
  ].join('\u0000');
  bool get _dirty => !_completed && (widget.isEditing
      ? _hydrated && _snapshot != _initialSnapshot
      : _listingId != null
      ? _snapshot != _initialSnapshot
      : _titleController.text.trim().isNotEmpty ||
          _descriptionController.text.trim().isNotEmpty ||
          _priceController.text.trim().isNotEmpty || _categorySlug != null ||
          _pickedStoreId != null || _priceOnRequest || _images.isNotEmpty);
  bool get _busy => _loading || _images.any((image) =>
      image.state == ListingImageUploadState.signing ||
      image.state == ListingImageUploadState.uploading ||
      image.state == ListingImageUploadState.confirming);
  void _leave() => _exitGuard.leave(context, dirty: _dirty, busy: _busy,
      refresh: () => setState(() {}), pop: () => context.pop());

  @override
  void initState() {
    super.initState();
    for (final controller in [_titleController, _descriptionController, _priceController]) {
      controller.addListener(_onDraftChanged);
    }
  }

  void _onDraftChanged() {
    if (mounted && (!widget.isEditing || _hydrated)) setState(() {});
  }

  static const _maxImages = 5;

  @override
  void dispose() {
    for (final controller in [_titleController, _descriptionController, _priceController]) {
      controller.removeListener(_onDraftChanged);
    }
    _uploadCancelToken.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _hydrateFrom(MarketplaceListing listing) {
    if (_hydrated) return;
    _listingId = listing.id;
    _loaded = listing;
    _titleController.text = listing.title;
    _descriptionController.text = listing.description ?? '';
    _categorySlug = listing.categorySlug;
    _priceOnRequest = listing.priceOnRequest || listing.price == null;
    if (listing.price != null && !listing.priceOnRequest) {
      _priceController.text = listing.price! % 1 == 0
          ? listing.price!.toStringAsFixed(0)
          : listing.price!.toStringAsFixed(2);
    }
    for (final img in listing.images) {
      _images.add(
        ListingImageDraft(
          localId: img.id,
          assetId: img.mediaAssetId,
          mediaUrl: img.imageUrl,
          state: ListingImageUploadState.ready,
          progress: 1,
        ),
      );
    }
    _initialSnapshot = _snapshot;
    _hydrated = true;
  }

  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 5 imágenes por publicación.')),
      );
      return;
    }
    try {
      final media = ref.read(marketplaceMediaServiceProvider);
      final draft = await media.pickAndPrepareDraft();
      setState(() => _images.add(draft));
      await _uploadDraft(draft);
    } on MarketplaceMediaException catch (e) {
      if (e.message.contains('cancel')) return;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos seleccionar la imagen.')),
      );
    }
  }

  Future<void> _uploadDraft(ListingImageDraft draft) async {
    if (!allowNetworkAction(context)) {
      draft.state = ListingImageUploadState.failed;
      setState(() {});
      return;
    }
    final media = ref.read(marketplaceMediaServiceProvider);
    setState(() {});
    try {
      await media.uploadDraft(
        draft,
        purpose: MediaUploadPurpose.marketplaceListing,
        canStartRemote: () => mounted && allowNetworkAction(context),
        cancelToken: _uploadCancelToken,
        onProgress: (_) {
          if (mounted) setState(() {});
        },
      );
      // DEMO_HARDENING_03: the photo joins the listing on "Guardar"/"Enviar"
      // as part of the ordered set (no per-photo attach, no duplicates).
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Falló la subida. Puedes reintentar.'),
          action: SnackBarAction(
            label: 'Reintentar',
            onPressed: () => _uploadDraft(draft),
          ),
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  String? _resolveStoreId() {
    final fixed = widget.storeId;
    if (fixed != null && fixed.isNotEmpty) return fixed;
    if (_eligibleStores.length == 1) return _eligibleStores.first.id;
    final picked = _pickedStoreId;
    if (picked != null && _eligibleStores.any((s) => s.id == picked)) {
      return picked;
    }
    return null;
  }

  /// Ordered photo set for the create/PATCH body: only uploaded (READY)
  /// photos, cover first. Failed or in-flight photos never reach the listing.
  List<SellerListingImageRef> _imageRefs() => [
    for (final draft in _images)
      if (draft.state == ListingImageUploadState.ready &&
          ((draft.assetId?.isNotEmpty ?? false) ||
              (draft.mediaUrl?.startsWith('https://') ?? false)))
        SellerListingImageRef(
          mediaAssetId: draft.assetId,
          imageUrl: draft.assetId == null ? draft.mediaUrl : null,
        ),
  ];

  void _invalidateSellerData() {
    ref.invalidate(sellerListingsProvider);
    ref.invalidate(sellerStoreListingsProvider);
    ref.invalidate(sellerSummaryProvider);
    ref.invalidate(marketplaceListingsProvider);
    ref.invalidate(marketplaceFeaturedProvider);
    final slug = widget.slug;
    if (slug != null && slug.isNotEmpty) {
      ref.invalidate(marketplaceListingDetailProvider(slug));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Back to where the seller came from (store page or panel); deep links
  /// without history land on the seller panel instead of a dead end.
  void _exitAfterSuccess() {
    _completed = true;
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go('/marketplace/seller/dashboard');
    }
  }

  Future<void> _save({bool submit = false}) async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    // DEMO_HARDENING_03: once created, later saves update the same listing
    // (a failed submit + retry must never create a duplicate).
    final updating = widget.isEditing || _listingId != null;
    final storeId = updating ? null : _resolveStoreId();
    if (!updating && storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige el negocio de esta publicaci\u00f3n.'),
        ),
      );
      return;
    }
    if (_categorySlug == null || _categorySlug!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría.')),
      );
      return;
    }
    if (_images.any((i) => i.state == ListingImageUploadState.signing || i.state == ListingImageUploadState.uploading || i.state == ListingImageUploadState.confirming)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espera a que terminen las subidas.')),
      );
      return;
    }
    if (_images.any((i) => i.state == ListingImageUploadState.failed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reintenta o quita la foto con error.')),
      );
      return;
    }

    if (!allowNetworkAction(context)) return;

    setState(() => _loading = true);
    final service = ref.read(marketplaceServiceProvider);
    final request = SellerListingRequest(
      title: _titleController.text,
      description: _descriptionController.text,
      categorySlug: _categorySlug!,
      priceOnRequest: _priceOnRequest,
      price: _priceOnRequest
          ? null
          : double.tryParse(_priceController.text.trim().replaceAll(',', '.')),
      images: _imageRefs(),
    );

    MarketplaceListing listing;
    try {
      if (updating) {
        // MARKETPLACE_V2_A0: the backend updates by listing id (UUID).
        final listingId = _listingId;
        if (listingId == null || listingId.isEmpty) {
          throw StateError('listing id not loaded');
        }
        listing = await service.updateSellerListing(listingId, request);
      } else {
        listing = await service.createSellerListingInStore(storeId!, request);
      }
      _listingId = listing.id;
      _loaded = listing;
      _initialSnapshot = _snapshot;
      _invalidateSellerData();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _toast(marketplaceListingErrorMessage(e));
      return;
    }

    if (submit) {
      try {
        listing = await service.submitSellerListing(listing.id);
        _loaded = listing;
        _invalidateSellerData();
      } catch (e) {
        if (mounted) setState(() => _loading = false);
        _toast(
          'Guardamos tu publicaci\u00f3n como borrador, pero no pudimos '
          'enviarla a revisi\u00f3n. ${marketplaceListingErrorMessage(e, fallback: 'Int\u00e9ntalo de nuevo.')}',
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _toast(
      submit
          ? 'Publicaci\u00f3n enviada a revisi\u00f3n. Aparecer\u00e1 en Marketplace cuando Garra la apruebe.'
          : listing.isPublished
          ? 'Cambios guardados.'
          : 'Publicaci\u00f3n guardada como borrador.',
    );
    _exitAfterSuccess();
  }

  Future<void> _archive() async {
    final listingId = _listingId;
    if (_loading || listingId == null || listingId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('\u00bfDesactivar publicaci\u00f3n?'),
        content: const Text(
          'Dejar\u00e1 de aparecer en Marketplace y nadie podr\u00e1 '
          'contactarte por ella. Esta acci\u00f3n no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('listing-archive-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!allowNetworkAction(context)) return;
    setState(() => _loading = true);
    try {
      final archived = await ref
          .read(marketplaceServiceProvider)
          .archiveSellerListing(listingId);
      _loaded = archived;
      _invalidateSellerData();
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Publicaci\u00f3n desactivada. Ya no aparece en Marketplace.');
      _exitAfterSuccess();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _toast(
        marketplaceListingErrorMessage(
          e,
          fallback:
              'No pudimos desactivar la publicaci\u00f3n. Int\u00e9ntalo de nuevo.',
        ),
      );
    }
  }

  static String _statusHint(MarketplaceListing listing) {
    switch (listing.status.toUpperCase()) {
      case 'DRAFT':
        return 'Solo t\u00fa la ves. Env\u00edala a revisi\u00f3n para publicarla.';
      case 'PENDING':
      case 'PENDING_REVIEW':
        return 'Garra la revisar\u00e1 antes de mostrarla en Marketplace.';
      case 'ACTIVE':
      case 'PUBLISHED':
        return 'Visible en Marketplace. Los cambios que guardes se ver\u00e1n ah\u00ed.';
      case 'REJECTED':
        return 'Aj\u00fastala y vuelve a enviarla a revisi\u00f3n.';
      case 'SUSPENDED':
        return 'Suspendida por moderaci\u00f3n: no se puede editar.';
      case 'ARCHIVED':
        return 'Ya no aparece en Marketplace y no se puede editar.';
      case 'SOLD_OUT':
        return 'Puedes volver a enviarla a revisi\u00f3n.';
      default:
        return '';
    }
  }

  Widget _storeSection(BuildContext context) {
    final storesAsync = ref.watch(sellerStoresProvider);
    return storesAsync.when(
      loading: () => const GarraSkeleton(height: 52),
      error: (_, _) =>
          GarraErrorState(onRetry: () => ref.invalidate(sellerStoresProvider)),
      data: (stores) {
        _eligibleStores = stores
            .where((s) => !s.isArchived && s.id.isNotEmpty)
            .toList();
        final fixed = widget.storeId;
        String? label;
        if (fixed != null && fixed.isNotEmpty) {
          final match = stores.where((s) => s.id == fixed);
          label = match.isEmpty ? null : match.first.name;
        } else if (_eligibleStores.length == 1) {
          label = _eligibleStores.first.name;
        }
        if (label != null) {
          return Text(
            'Negocio: $label',
            key: const Key('listing-store-current'),
            style: Theme.of(context).textTheme.titleSmall,
          );
        }
        if (fixed != null && fixed.isNotEmpty) return const SizedBox.shrink();
        if (_eligibleStores.isEmpty) {
          return const Text(
            'Primero crea un negocio desde tu panel de vendedor.',
            key: Key('listing-store-none'),
          );
        }
        final picked = _eligibleStores.any((s) => s.id == _pickedStoreId)
            ? _pickedStoreId
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GarraFieldLabel('Negocio'),
            DropdownButtonFormField<String>(
              key: const Key('listing-store-select'),
              // ignore: deprecated_member_use
              value: picked,
              hint: const Text('Elige el negocio'),
              decoration: garraControlDecoration(context),
              dropdownColor: Theme.of(context).colorScheme.surface,
              items: [
                for (final store in _eligibleStores)
                  DropdownMenuItem(value: store.id, child: Text(store.name)),
              ],
              validator: (value) => value == null ? 'Elige el negocio' : null,
              onChanged: (value) => setState(() => _pickedStoreId = value),
            ),
          ],
        );
      },
    );
  }

  /// DEMO_HARDENING_03: CTAs follow the backend lifecycle. New/draft/rejected
  /// listings are published by sending them to review (primary); "Guardar"
  /// keeps a draft. Live or pending listings only save changes. Archived or
  /// suspended listings are read-only. Deactivate (archive) needs confirmation.
  List<Widget> _actions(BuildContext context) {
    final loaded = _loaded;
    if (loaded != null && !loaded.isEditableByOwner) return const [];
    final canSubmit = loaded == null || loaded.canSubmitForReview;
    return [
      if (canSubmit) ...[
        GarraPrimaryButton(
          key: const Key('listing-submit'),
          label: 'Enviar a revisi\u00f3n',
          loading: _loading,
          onPressed: _loading ? null : () => _save(submit: true),
        ),
        const SizedBox(height: GarraSpacing.md),
        GarraSecondaryButton(
          key: const Key('listing-save'),
          label: 'Guardar',
          onPressed: _loading ? null : () => _save(),
        ),
        const SizedBox(height: GarraSpacing.sm),
        Text(
          'Guardar la deja como borrador. Garra revisa cada publicaci\u00f3n '
          'antes de mostrarla en Marketplace.',
          key: const Key('listing-review-note'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.garraColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ] else
        GarraPrimaryButton(
          key: const Key('listing-save'),
          label: 'Guardar',
          loading: _loading,
          onPressed: _loading ? null : () => _save(),
        ),
      if (_listingId != null && loaded != null) ...[
        const SizedBox(height: GarraSpacing.xl),
        TextButton.icon(
          key: const Key('listing-archive'),
          onPressed: _loading ? null : _archive,
          icon: const Icon(Icons.visibility_off_outlined),
          label: const Text('Desactivar publicaci\u00f3n'),
        ),
      ],
    ];
  }

  Widget _statusBanner(BuildContext context, MarketplaceListing listing) {
    return GarraCard(
      key: const Key('listing-status-banner'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado: ${marketplaceListingStatusLabel(listing.status)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (_statusHint(listing).isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.xs),
            Text(
              _statusHint(listing),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(marketplaceCategoriesProvider);

    if (widget.isEditing) {
      final listingAsync = ref.watch(
        marketplaceListingDetailProvider(widget.slug!),
      );
      listingAsync.whenData(_hydrateFrom);
      // DEMO_HARDENING_03: never show an empty, unsavable edit form.
      if (!_hydrated) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar publicaci\u00f3n')),
          body: listingAsync.hasError
              ? GarraErrorState(
                  title: 'No pudimos cargar tu publicaci\u00f3n',
                  onRetry: () => ref.invalidate(
                    marketplaceListingDetailProvider(widget.slug!),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.all(GarraSpacing.lg),
                  child: GarraSkeleton(height: 220),
                ),
        );
      }
    }

    return PopScope(
      canPop: _exitGuard.canPop(dirty: _dirty, busy: _busy),
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _leave(); },
      child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text(
          widget.isEditing ? 'Editar publicación' : 'Nueva publicación',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.lg,
            GarraSpacing.md,
            GarraSpacing.lg,
            GarraSpacing.section,
          ),
          children: [
            GarraFormIntro(
              title: widget.isEditing ? 'Editar anuncio' : 'Nuevo anuncio',
              subtitle:
                  'Esto se publica en Marketplace, aparte de tu ficha en Negocios Cremas.',
            ),
            if (_loaded != null) ...[
              _statusBanner(context, _loaded!),
              const SizedBox(height: GarraSpacing.lg),
            ],
            if (!widget.isEditing) ...[
              _storeSection(context),
              const SizedBox(height: GarraSpacing.lg),
            ],
            Text(
              'Fotos (máx. $_maxImages) — la primera es la portada',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: GarraSpacing.sm),
            SizedBox(
              height: 110,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                onReorder: _reorder,
                itemCount:
                    _images.length + (_images.length < _maxImages ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _images.length) {
                    return Padding(
                      key: const ValueKey('add'),
                      padding: const EdgeInsets.only(right: GarraSpacing.sm),
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(GarraRadius.md),
                        child: Container(
                          width: 96,
                          decoration: BoxDecoration(
                            color: context.garraColors.surface,
                            borderRadius: BorderRadius.circular(GarraRadius.md),
                            border: Border.all(
                              color: const Color(GarraColors.borderSubtle),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: context.garraColors.brandPrestige,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Agregar',
                                style: TextStyle(
                                  color: context.garraColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final draft = _images[index];
                  return Padding(
                    key: ValueKey(draft.localId),
                    padding: const EdgeInsets.only(right: GarraSpacing.sm),
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          decoration: BoxDecoration(
                            color: context.garraColors.surface,
                            borderRadius: BorderRadius.circular(GarraRadius.md),
                            border: Border.all(
                              color: const Color(GarraColors.borderSubtle),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: draft.bytes != null
                              ? Image.memory(draft.bytes!, fit: BoxFit.cover)
                              : draft.mediaUrl != null
                              ? Image.network(
                                  draft.mediaUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.broken_image_outlined,
                                    color: context.garraColors.brandPrestige,
                                  ),
                                )
                              : Icon(
                                  Icons.image_outlined,
                                  color: context.garraColors.brandPrestige,
                                ),
                        ),
                        if (draft.state == ListingImageUploadState.uploading ||
                            draft.state == ListingImageUploadState.pending)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black45,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                value: draft.progress > 0
                                    ? draft.progress
                                    : null,
                                color: context.garraColors.brandPrestige,
                              ),
                            ),
                          ),
                        if (draft.state == ListingImageUploadState.failed)
                          Positioned.fill(
                            child: Material(
                              color: Colors.black54,
                              child: InkWell(
                                onTap: () => _uploadDraft(draft),
                                child: Center(
                                  child: Icon(
                                    Icons.refresh,
                                    color: context.garraColors.brandPrestige,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: () => _removeImage(index),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                        if (index == 0)
                          const Positioned(
                            left: 4,
                            bottom: 4,
                            child: Text(
                              'Portada',
                              style: TextStyle(
                                color: Color(GarraColors.gold),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: GarraSpacing.xxl),
            GarraFormSection(
              title: 'PUBLICACIÓN',
              children: [
                GarraTextField(
                  label: 'Título',
                  controller: _titleController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un título';
                    }
                    if (value.trim().length > 160) {
                      return 'M\u00e1ximo 160 caracteres';
                    }
                    return null;
                  },
                ),
                GarraTextArea(
                  label: 'Descripción',
                  controller: _descriptionController,
                  minLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa una descripción';
                    }
                    if (value.trim().length > 4000) {
                      return 'M\u00e1ximo 4000 caracteres';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: GarraSpacing.lg),
            categoriesAsync.when(
              loading: () => const GarraSkeleton(height: 52),
              error: (_, _) => GarraErrorState(
                onRetry: () => ref.invalidate(marketplaceCategoriesProvider),
              ),
              data: (categories) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GarraFieldLabel('Categoría'),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value:
                          _categorySlug != null &&
                              categories.any((c) => c.slug == _categorySlug)
                          ? _categorySlug
                          : null,
                      decoration: garraControlDecoration(context),
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      items: [
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category.slug,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _categorySlug = value),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: GarraSpacing.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Precio a consultar'),
              value: _priceOnRequest,
              activeThumbColor: const Color(GarraColors.gold),
              onChanged: (value) => setState(() => _priceOnRequest = value),
            ),
            if (!_priceOnRequest) ...[
              const SizedBox(height: GarraSpacing.md),
              GarraTextField(
                label: 'Precio (S/)',
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (_priceOnRequest) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un precio o marca consultar';
                  }
                  final raw = value.trim();
                  // NUMERIC(12,2) in the backend: up to 10 digits, 2 decimals.
                  if (!RegExp(r'^\d{1,10}([.,]\d{1,2})?$').hasMatch(raw)) {
                    return 'Precio inválido';
                  }
                  final parsed = double.tryParse(raw.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return 'Ingresa un precio mayor a 0 o marca consultar';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: GarraSpacing.xxl),
            ..._actions(context),
          ],
        ),
      ),
    ));
  }
}
