import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_models.dart';
import '../data/marketplace_url_launcher.dart';
import '../widgets/garra_marketplace_card.dart';
import 'providers/marketplace_provider.dart';

class StorePage extends ConsumerWidget {
  const StorePage({super.key, required this.slug});

  final String slug;

  Future<void> _openWhatsApp(
    BuildContext context,
    MarketplaceStore store,
  ) async {
    final raw = store.whatsapp?.trim() ?? '';
    final directUri = Uri.tryParse(raw);
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final uri =
        directUri != null &&
            (directUri.scheme == 'http' || directUri.scheme == 'https')
        ? directUri
        : digits.isEmpty
        ? null
        : Uri.https('wa.me', '/$digits');

    if (uri == null) return;
    try {
      final launched = await marketplaceUrlLauncher(uri);
      if (!launched && context.mounted) {
        _showLaunchError(context);
      }
    } catch (_) {
      if (context.mounted) _showLaunchError(context);
    }
  }

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir WhatsApp. Inténtalo de nuevo.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceStoreProvider(slug));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Tienda crema')),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () => ref.invalidate(marketplaceStoreProvider(slug)),
        ),
        data: (store) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.md,
              GarraSpacing.lg,
              GarraSpacing.section,
            ),
            children: [
              _StoreHero(store: store),
              if ((store.whatsapp?.trim().isNotEmpty ?? false) ||
                  store.isCremaPointVerified) ...[
                const SizedBox(height: GarraSpacing.md),
                Row(
                  children: [
                    if (store.whatsapp?.trim().isNotEmpty ?? false)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openWhatsApp(context, store),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text(
                            'WhatsApp',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if ((store.whatsapp?.trim().isNotEmpty ?? false) &&
                        store.isCremaPointVerified)
                      const SizedBox(width: GarraSpacing.sm),
                    if (store.isCremaPointVerified)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/mapa-crema'),
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text(
                            'Cómo llegar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (store.description != null &&
                  store.description!.trim().isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.lg),
                Text(
                  store.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: GarraSpacing.xxl),
              const GarraSectionHeader(title: 'Publicaciones'),
              const SizedBox(height: GarraSpacing.md),
              if (store.listings.isEmpty)
                const GarraEmptyState(
                  title: 'Sin publicaciones',
                  message: 'Esta tienda aún no tiene publicaciones activas.',
                )
              else
                for (final listing in store.listings) ...[
                  GarraMarketplaceCard(
                    listing: listing,
                    showFavorite: false,
                    onTap: () =>
                        context.push('/marketplace/listings/${listing.slug}'),
                  ),
                  const SizedBox(height: GarraSpacing.md),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.store});

  final MarketplaceStore store;

  @override
  Widget build(BuildContext context) {
    final hasBanner = store.bannerUrl?.isNotEmpty ?? false;
    final hasLogo = store.logoUrl?.isNotEmpty ?? false;

    return Container(
      height: 210,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GarraRadius.xl),
        border: Border.all(color: const Color(GarraColors.borderSubtle)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBanner)
            CachedNetworkImage(
              imageUrl: store.bannerUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: Color(GarraColors.burgundyDeep)),
            )
          else
            Image.asset(
              'assets/visual/garra_match_hero.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(GarraColors.burgundyDeep)),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x10171311), Color(0xF2171311)],
                stops: [0.25, 1],
              ),
            ),
          ),
          Positioned(
            left: GarraSpacing.lg,
            right: GarraSpacing.lg,
            bottom: GarraSpacing.lg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(GarraRadius.md),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: hasLogo
                        ? CachedNetworkImage(
                            imageUrl: store.logoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                const _StoreLogoFallback(),
                          )
                        : const _StoreLogoFallback(),
                  ),
                ),
                const SizedBox(width: GarraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        store.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(GarraColors.cream),
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                      ),
                      if (store.isCremaPointVerified) ...[
                        const SizedBox(height: GarraSpacing.xs),
                        const Text(
                          '✓ Punto Crema verificado',
                          style: TextStyle(
                            color: Color(GarraColors.gold),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ] else if (store.city?.isNotEmpty ?? false) ...[
                        const SizedBox(height: GarraSpacing.xs),
                        Text(
                          store.city!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(GarraColors.creamMuted),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreLogoFallback extends StatelessWidget {
  const _StoreLogoFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(GarraColors.surface),
      child: Icon(Icons.storefront_outlined, color: Color(GarraColors.gold)),
    );
  }
}
