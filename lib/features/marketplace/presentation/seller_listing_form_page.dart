import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
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
    _titleController.text = listing.title;
    _descriptionController.text = listing.description ?? '';
    _categorySlug = listing.categorySlug;
    _priceOnRequest = listing.priceOnRequest || listing.price == null;
    if (listing.price != null && !listing.priceOnRequest) {
      _priceController.text = listing.price! % 1 == 0
          ? listing.price!.toStringAsFixed(0)
          : listing.price!.toStringAsFixed(2);
    }
  }

  Future<void> _save({bool submit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_categorySlug == null || _categorySlug!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = ref.read(marketplaceServiceProvider);
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
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(GarraColors.surface),
                borderRadius: BorderRadius.circular(GarraRadius.xl),
                border: Border.all(color: const Color(GarraColors.borderSubtle)),
              ),
              child: Text(
                'Fotos disponibles próximamente',
                style: Theme.of(context).textTheme.bodySmall,
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
