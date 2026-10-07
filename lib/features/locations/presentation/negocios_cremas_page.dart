import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../data/crema_business_engagement_service.dart';
import '../data/crema_business_offer_models.dart';
import '../data/crema_point_model.dart';
import '../../community/presentation/widgets/garra_tribuna_offer_card.dart';
import '../data/location_service.dart';
import '../data/business_social_links.dart';
import '../data/business_map_links.dart';
import '../../marketplace/data/marketplace_url_launcher.dart';
import '../../../core/widgets/garra_cached_network_image.dart';
import '../../community/presentation/widgets/garra_post_media_grid.dart'
    show openGarraMediaViewer;
import 'mi_negocio_crema_page.dart' show BusinessCoverThumb;

/// Registered crema businesses. Separate from Marketplace listings and from
/// the stadium route.
class NegociosCremasPage extends StatelessWidget {
  const NegociosCremasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Negocios Cremas')),
      body: ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          Text(
            'Negocios registrados de la hinchada. El Marketplace sigue siendo el lugar de los anuncios.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: GarraSpacing.lg),
          _Action(
            icon: Icons.storefront_outlined,
            title: 'Ver negocios',
            subtitle: 'Recorre los puntos crema registrados',
            onTap: () => context.push('/negocios/buscar'),
          ),
          _Action(
            icon: Icons.map_outlined,
            title: 'Mapa',
            subtitle: 'Dónde están los negocios cremas',
            onTap: () => context.push('/negocios/mapa'),
          ),
          _Action(
            icon: Icons.add_business_outlined,
            title: 'Mis negocios',
            subtitle: 'Tus solicitudes y tus negocios aprobados',
            onTap: () => context.push('/negocios/mi-negocio'),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
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
    return Card(
      color: context.garraColors.surface,
      child: ListTile(
        leading: Icon(icon, color: context.garraColors.brandPrestige),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

class NegociosCremasBrowsePage extends StatefulWidget {
  const NegociosCremasBrowsePage({super.key, this.locationService});

  final LocationService? locationService;

  @override
  State<NegociosCremasBrowsePage> createState() =>
      _NegociosCremasBrowsePageState();
}

class _NegociosCremasBrowsePageState extends State<NegociosCremasBrowsePage> {
  late final LocationService _service =
      widget.locationService ?? LocationService();
  final _query = TextEditingController();
  var _verifiedOnly = false;
  var _loading = true;
  String? _error;
  List<CremaPointModel> _points = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final points = await _service.getActivePoints();
      if (!mounted) return;
      setState(() {
        _points = points
            .where((point) => point.type.toUpperCase() == 'BUSINESS')
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los negocios';
        _loading = false;
      });
    }
  }

  List<CremaPointModel> get _visible {
    final query = _query.text.trim().toLowerCase();
    return _points.where((point) {
      if (_verifiedOnly && !point.verified) return false;
      if (query.isEmpty) return true;
      return point.name.toLowerCase().contains(query) ||
          point.address.toLowerCase().contains(query);
    }).toList();
  }

  Widget _browseBody(BuildContext context, List<CremaPointModel> visible) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_points.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(GarraSpacing.lg),
          child: Text(
            'No hay negocios registrados todavía',
            key: Key('negocios-empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (visible.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(GarraSpacing.lg),
          child: Text(
            'Ningún negocio coincide con la búsqueda',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.sm,
        GarraSpacing.lg,
        GarraSpacing.lg,
      ),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _BusinessCard(point: visible[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(title: const Text('Negocios Cremas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.md,
              GarraSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Buscar',
                hintText: 'Nombre o dirección',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.sm),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: !_verifiedOnly,
                  onSelected: (_) => setState(() => _verifiedOnly = false),
                ),
                FilterChip(
                  label: const Text('Verificados'),
                  selected: _verifiedOnly,
                  onSelected: (_) => setState(() => _verifiedOnly = true),
                ),
              ],
            ),
          ),
          Expanded(child: _browseBody(context, visible)),
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.point});

  final CremaPointModel point;

  @override
  Widget build(BuildContext context) {
    final copy = BusinessCopy.parse(point.description);
    return Card(
      color: context.garraColors.surface,
      child: InkWell(
        onTap: () => context.push('/negocios/${point.id}'),
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if ((point.coverImageUrl ?? '').isNotEmpty) ...[
                    BusinessCoverThumb(url: point.coverImageUrl, size: 44),
                    const SizedBox(width: GarraSpacing.md),
                  ],
                  Expanded(
                    child: Text(
                      point.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (point.verified)
                    Text(
                      'Verificado',
                      style: TextStyle(
                        color: context.garraColors.brandPrestige,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (point.category != null || copy.category != null) ...[
                const SizedBox(height: 4),
                Text(
                  point.category ?? copy.category!,
                  style: TextStyle(color: context.garraColors.brandPrestige),
                ),
              ],
              const SizedBox(height: 4),
              Text(publicBusinessArea(point.address)),
              if (copy.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(copy.description),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      context.push('/negocios/mapa?pointId=${point.id}'),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Ver en el mapa'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusinessCopy {
  const BusinessCopy(this.category, this.description);

  final String? category;
  final String description;

  static BusinessCopy parse(String? raw) {
    final text = raw?.trim() ?? '';
    const mark = ' · ';
    final index = text.indexOf(mark);
    if (index <= 0) return BusinessCopy(null, text);
    return BusinessCopy(
      text.substring(0, index),
      text.substring(index + mark.length),
    );
  }
}

class NegocioCremaDetailPage extends StatefulWidget {
  const NegocioCremaDetailPage({
    super.key,
    required this.idOrSlug,
    this.locationService,
    this.engagement,
  });

  final String idOrSlug;
  final LocationService? locationService;
  final CremaBusinessEngagementService? engagement;

  @override
  State<NegocioCremaDetailPage> createState() => _NegocioCremaDetailPageState();
}

class _NegocioCremaDetailPageState extends State<NegocioCremaDetailPage> {
  late final LocationService _service =
      widget.locationService ?? LocationService();
  late final CremaBusinessEngagementService _engagement =
      widget.engagement ?? CremaBusinessEngagementService();
  CremaPointModel? _point;
  List<CremaBusinessOffer> _offers = const [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final points = await _service.getActivePoints();
      final key = widget.idOrSlug.toLowerCase();
      CremaPointModel? match;
      for (final point in points) {
        if (point.id == widget.idOrSlug ||
            point.name.toLowerCase().replaceAll(' ', '-') == key) {
          match = point;
          break;
        }
      }
      var offers = const <CremaBusinessOffer>[];
      if (match != null) {
        try {
          offers = await _engagement.listPointOffers(match.id).timeout(const Duration(seconds: 8), onTimeout: () => const <CremaBusinessOffer>[]);
        } catch (_) {
          offers = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _point = match;
        _offers = offers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos cargar este negocio';
      });
    }
  }

  Future<void> _openLink(Uri uri) async {
    try {
      if (await marketplaceUrlLauncher(uri)) return;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    return Scaffold(
      appBar: AppBar(title: Text(point?.name ?? 'Negocio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            )
          : point == null
          ? const Center(child: Text('No encontramos este negocio'))
          : ListView(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              children: [
                if ((point.coverImageUrl ?? '').isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: GestureDetector(
                        onTap: () =>
                            openGarraMediaViewer(context, [point.coverImageUrl!]),
                        child: GarraCachedNetworkImage(
                          imageUrl: point.coverImageUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  point.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(publicBusinessArea(point.address))),
                  ],
                ),
                if ((point.category ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    point.category!,
                    style: TextStyle(
                      color: context.garraColors.brandPrestige,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (point.verified) ...[
                  const SizedBox(height: 8),
                  const Chip(label: Text('Verificado por Garra')),
                ],
                if ((point.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(point.description!),
                ],
                if ((point.phone ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openLink(Uri(scheme: 'tel', path: point.phone)),
                    icon: const Icon(Icons.call_outlined),
                    label: Text('Llamar · ${point.phone}'),
                  ),
                ],
                if ((point.whatsapp ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      final digits = point.whatsapp!.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      if (digits.isNotEmpty) {
                        _openLink(Uri.https('wa.me', '/$digits'));
                      }
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ],
                if ([
                  point.instagram,
                  point.facebook,
                  point.tiktok,
                ].any((value) => value?.isNotEmpty == true)) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Redes sociales',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (network, value)
                          in <(BusinessSocialNetwork, String?)>[
                            (BusinessSocialNetwork.instagram, point.instagram),
                            (BusinessSocialNetwork.facebook, point.facebook),
                            (BusinessSocialNetwork.tiktok, point.tiktok),
                          ])
                        if (businessSocialUri(network, value) != null)
                          ActionChip(
                            avatar: const Icon(Icons.open_in_new, size: 16),
                            label: Text(socialNetworkLabel(network)),
                            onPressed: () async {
                              if (await openBusinessSocial(network, value)) {
                                return;
                              }
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo abrir la red social',
                                  ),
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ],
                if (_offers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'OFERTAS Y PROMOCIONES',
                    key: const ValueKey('public_business_offers_header'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: context.garraColors.brandPrestige,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final offer in _offers)
                    GarraTribunaOfferCard(
                      key: ValueKey('public_business_offer_${offer.id}'),
                      offer: offer,
                      compact: true,
                    ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _openLink(
                    businessDirectionsUri(point.latitude, point.longitude)),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Cómo llegar'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () =>
                      context.push('/negocios/mapa?pointId=${point.id}'),
                  child: const Text('Ver ubicación del negocio'),
                ),
              ],
            ),
    );
  }
}
