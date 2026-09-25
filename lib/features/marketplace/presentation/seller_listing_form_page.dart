import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_media_service.dart';
import '../data/marketplace_models.dart';
import 'providers/marketplace_provider.dart';

class SellerListingFormPage extends ConsumerStatefulWidget {
  const SellerListingFormPage({super.key, this.slug});

  final String? slug;

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
  final List<ListingImageDraft> _images = [];

  static const _maxImages = 5;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _hydrateFrom(MarketplaceListing listing) {
    if (_hydrated) return;
    _hydrated = true;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos seleccionar la imagen.')),
      );
    }
  }

  Future<void> _uploadDraft(ListingImageDraft draft) async {
    final media = ref.read(marketplaceMediaServiceProvider);
    setState(() {});
    try {
      await media.uploadDraft(
        draft,
        purpose: MediaUploadPurpose.marketplaceListing,
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

  Future<void> _save({bool submit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_categorySlug == null || _categorySlug!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría.')),
      );
      return;
    }
    if (_images.any((i) => i.state == ListingImageUploadState.uploading)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espera a que terminen las subidas.')),
      );
      return;
    }

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
        listing = await service.updateSellerListing(widget.slug!, request);
      } else {
        listing = await service.createSellerListing(request);
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
        listing = await service.submitSellerListing(listing.slug);
      }

      ref.invalidate(sellerListingsProvider);
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
          content: Text('No pudimos guardar la publicación. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(marketplaceCategoriesProvider);

    if (widget.isEditing) {
      final listingAsync =
          ref.watch(marketplaceListingDetailProvider(widget.slug!));
      listingAsync.whenData(_hydrateFrom);
    }

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar publicación' : 'Nueva publicación'),
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
              subtitle: 'Esto se publica en Marketplace, aparte de tu ficha en Negocios Cremas.',
            ),
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
                itemCount: _images.length + (_images.length < _maxImages ? 1 : 0),
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
                            color: const Color(GarraColors.surface),
                            borderRadius: BorderRadius.circular(GarraRadius.md),
                            border: Border.all(
                              color: const Color(GarraColors.borderSubtle),
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: Color(GarraColors.gold)),
                              SizedBox(height: 4),
                              Text('Agregar',
                                  style: TextStyle(
                                      color: Color(GarraColors.textSecondary),
                                      fontSize: 12)),
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
                            color: const Color(GarraColors.surface),
                            borderRadius: BorderRadius.circular(GarraRadius.md),
                            border: Border.all(
                              color: const Color(GarraColors.borderSubtle),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: draft.bytes != null
                              ? Image.memory(draft.bytes!, fit: BoxFit.cover)
                              : draft.mediaUrl != null
                                  ? Image.network(draft.mediaUrl!,
                                      fit: BoxFit.cover)
                                  : const Icon(Icons.image_outlined,
                                      color: Color(GarraColors.gold)),
                        ),
                        if (draft.state == ListingImageUploadState.uploading ||
                            draft.state == ListingImageUploadState.pending)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black45,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                value: draft.progress > 0 ? draft.progress : null,
                                color: const Color(GarraColors.gold),
                              ),
                            ),
                          ),
                        if (draft.state == ListingImageUploadState.failed)
                          Positioned.fill(
                            child: Material(
                              color: Colors.black54,
                              child: InkWell(
                                onTap: () => _uploadDraft(draft),
                                child: const Center(
                                  child: Icon(Icons.refresh,
                                      color: Color(GarraColors.gold)),
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
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un título';
                }
                return null;
              },
            ),
            const SizedBox(height: GarraSpacing.lg),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa una descripción';
                }
                return null;
              },
            ),
            const SizedBox(height: GarraSpacing.lg),
            categoriesAsync.when(
              loading: () => const GarraSkeleton(height: 52),
              error: (_, _) => GarraErrorState(
                onRetry: () => ref.invalidate(marketplaceCategoriesProvider),
              ),
              data: (categories) {
                return DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _categorySlug != null &&
                          categories.any((c) => c.slug == _categorySlug)
                      ? _categorySlug
                      : null,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.slug,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categorySlug = value),
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
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio (S/)',
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
    );
  }
}
