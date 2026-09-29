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
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_media_service.dart';
import '../data/marketplace_models.dart';
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
      _completed = true;
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
      if (_listingId != null && draft.assetId != null) {
        await media.attachListingImage(
          listingId: _listingId!,
          mediaAssetId: draft.assetId!,
        );
      }
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

  Future<void> _save({bool submit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final storeId = widget.isEditing ? null : _resolveStoreId();
    if (!widget.isEditing && storeId == null) {
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
    try {
      final service = ref.read(marketplaceServiceProvider);
      final media = ref.read(marketplaceMediaServiceProvider);
      final request = SellerListingRequest(
        title: _titleController.text,
        description: _descriptionController.text,
        categorySlug: _categorySlug!,
        priceOnRequest: _priceOnRequest,
        price: _priceOnRequest
            ? null
            : double.tryParse(_priceController.text.replaceAll(',', '.')),
      );

      MarketplaceListing listing;
      if (widget.isEditing) {
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

      for (var i = 0; i < _images.length; i++) {
        final draft = _images[i];
        if (draft.isReady && draft.assetId != null) {
          try {
            await media.attachListingImage(
              listingId: listing.id,
              mediaAssetId: draft.assetId!,
              sortOrder: i,
            );
          } catch (_) {
            // Idempotent attach best-effort for drafts created before listing id.
          }
        }
      }

      if (submit) {
        listing = await service.submitSellerListing(listing.id);
      }

      ref.invalidate(sellerListingsProvider);
      ref.invalidate(sellerStoreListingsProvider);
      ref.invalidate(sellerSummaryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submit
                ? 'Publicación enviada a revisión.'
                : 'Publicación guardada.',
          ),
        ),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos guardar la publicación. Inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(marketplaceCategoriesProvider);

    if (widget.isEditing) {
      final listingAsync = ref.watch(
        marketplaceListingDetailProvider(widget.slug!),
      );
      listingAsync.whenData(_hydrateFrom);
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
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Precio inválido';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: GarraSpacing.xxl),
            GarraPrimaryButton(
              label: 'Guardar',
              loading: _loading,
              onPressed: () => _save(),
            ),
            const SizedBox(height: GarraSpacing.md),
            GarraSecondaryButton(
              label: 'Enviar a revisión',
              onPressed: _loading ? null : () => _save(submit: true),
            ),
          ],
        ),
      ),
    ));
  }
}
