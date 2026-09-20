import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_models.dart';
import '../data/marketplace_service.dart';
import '../data/marketplace_url_launcher.dart';
import 'providers/marketplace_provider.dart';

class ListingDetailPage extends ConsumerStatefulWidget {
  const ListingDetailPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends ConsumerState<ListingDetailPage> {
  MarketplaceListing? _localListing;
  bool _contacting = false;
  bool _favoriting = false;

  Future<void> _toggleFavorite(MarketplaceListing listing) async {
    if (_favoriting) return;
    final previous = _localListing ?? listing;
    final nextFavorite = !previous.isFavorite;

    setState(() {
      _favoriting = true;
      _localListing = previous.copyWith(isFavorite: nextFavorite);
    });

    try {
      final service = ref.read(marketplaceServiceProvider);
      if (nextFavorite) {
        await service.addFavorite(listing.slug);
      } else {
        await service.removeFavorite(listing.slug);
      }
      ref.invalidate(marketplaceFavoritesProvider);
      ref.invalidate(marketplaceListingDetailProvider(widget.slug));
    } catch (_) {
      if (!mounted) return;
      setState(() => _localListing = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos actualizar el favorito. Inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _favoriting = false);
    }
  }

  Future<void> _contact(MarketplaceListing listing) async {
    if (_contacting) return;
    setState(() => _contacting = true);
    try {
      final result = await ref
          .read(marketplaceServiceProvider)
          .contactListing(listing.slug);
      final uri = Uri.tryParse(result.whatsappUri);
      if (uri == null) {
        throw MarketplaceServiceException(
          'No pudimos abrir WhatsApp. Inténtalo de nuevo.',
        );
      }
      try {
        final launched = await marketplaceUrlLauncher(uri);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pudimos abrir WhatsApp. Inténtalo de nuevo.'),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pudimos abrir WhatsApp. Inténtalo de nuevo.'),
            ),
          );
        }
      }
    } on MarketplaceServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir WhatsApp. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  Future<void> _report(MarketplaceListing listing) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(GarraColors.surface),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(GarraSpacing.lg),
                child: Text(
                  'Reportar publicación',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                title: const Text('Contenido inapropiado'),
                onTap: () => Navigator.pop(context, 'INAPPROPRIATE'),
              ),
              ListTile(
                title: const Text('Spam o engaño'),
                onTap: () => Navigator.pop(context, 'SPAM'),
              ),
              ListTile(
                title: const Text('Derechos de autor / marca'),
                onTap: () => Navigator.pop(context, 'IP'),
              ),
              ListTile(
                title: const Text('Otro'),
                onTap: () => Navigator.pop(context, 'OTHER'),
              ),
              const SizedBox(height: GarraSpacing.md),
            ],
          ),
        );
      },
    );
    if (reason == null || !mounted) return;

    try {
      await ref.read(marketplaceServiceProvider).reportListing(
            MarketplaceReportRequest(
              listingSlug: listing.slug,
              reason: reason,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias. Revisaremos el reporte.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is MarketplaceServiceException
          ? e.message
          : 'No pudimos enviar el reporte. Inténtalo de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(marketplaceListingDetailProvider(widget.slug));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Publicación'),
        actions: [
          async.maybeWhen(
            data: (listing) {
              final current = _localListing ?? listing;
              return IconButton(
                tooltip: current.isFavorite
                    ? 'Quitar de favoritos'
                    : 'Agregar a favoritos',
                onPressed: () => _toggleFavorite(listing),
                icon: Icon(
                  current.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: current.isFavorite
                      ? const Color(GarraColors.garnet)
                      : null,
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Reportar',
            onPressed: async.maybeWhen(
              data: (listing) => () => _report(listing),
              orElse: () => null,
            ),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () =>
              ref.invalidate(marketplaceListingDetailProvider(widget.slug)),
        ),
        data: (listing) {
          final current = _localListing ?? listing;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.md,
              GarraSpacing.lg,
              GarraSpacing.section,
            ),
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(GarraColors.garnet).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(GarraRadius.xl),
                  border: Border.all(
                    color: const Color(GarraColors.borderSubtle),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Fotos disponibles próximamente',
                    style: TextStyle(color: Color(GarraColors.textSecondary)),
                  ),
                ),
              ),
              const SizedBox(height: GarraSpacing.xl),
              Text(
                current.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                current.priceLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(GarraColors.gold),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (current.category != null && current.category!.isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  current.category!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (current.store != null) ...[
                const SizedBox(height: GarraSpacing.lg),
                GarraCard(
                  onTap: () => context.push(
                    '/marketplace/stores/${current.store!.slug}',
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.store_mall_directory_outlined,
                        color: Color(GarraColors.gold),
                      ),
                      const SizedBox(width: GarraSpacing.md),
                      Expanded(
                        child: Text(
                          current.store!.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(GarraColors.gold),
                      ),
                    ],
                  ),
                ),
              ],
              if (current.description != null &&
                  current.description!.trim().isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.xxl),
                Text(
                  'Descripción',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  current.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: GarraSpacing.xxl),
              GarraPrimaryButton(
                label: 'Contactar por WhatsApp',
                loading: _contacting,
                onPressed: () => _contact(current),
              ),
              const SizedBox(height: GarraSpacing.md),
              Text(
                'Sin compra en la app. Coordina directamente con el vendedor.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
