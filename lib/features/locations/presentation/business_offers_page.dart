import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/crema_business_engagement_service.dart';
import '../data/crema_business_offer_models.dart';

class BusinessOffersPage extends StatefulWidget {
  const BusinessOffersPage({super.key, this.service});

  final CremaBusinessEngagementService? service;

  @override
  State<BusinessOffersPage> createState() => _BusinessOffersPageState();
}

class _BusinessOffersPageState extends State<BusinessOffersPage> {
  late final _service = widget.service ?? CremaBusinessEngagementService();
  List<CremaBusinessOffer> _offers = [];
  bool _loading = true;
  bool _nearby = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(nearby: false);
  }

  Future<void> _load({required bool nearby}) async {
    setState(() {
      _loading = true;
      _error = null;
      _nearby = nearby;
    });
    try {
      List<CremaBusinessOffer> offers;
      if (nearby) {
        final permission = await Geolocator.checkPermission();
        LocationPermission p = permission;
        if (p == LocationPermission.denied) {
          p = await Geolocator.requestPermission();
        }
        if (p == LocationPermission.denied ||
            p == LocationPermission.deniedForever) {
          offers = await _service.listOffers();
          if (!mounted) return;
          setState(() {
            _offers = offers;
            _nearby = false;
            _loading = false;
            _error = 'Sin ubicación: mostrando ofertas generales';
          });
          return;
        }
        final pos = await Geolocator.getCurrentPosition();
        offers = await _service.listOffers(
          lat: pos.latitude,
          lng: pos.longitude,
          radiusKm: 8,
        );
      } else {
        offers = await _service.listOffers();
      }
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar ofertas';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(
        title: Text(_nearby ? 'Cerca de ti' : 'Ofertas crema'),
        actions: [
          TextButton(
            onPressed: () => _load(nearby: !_nearby),
            child: Text(_nearby ? 'Todas' : 'Cerca de ti'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(nearby: _nearby),
              child: ListView(
                padding: const EdgeInsets.all(GarraSpacing.lg),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                  ],
                  if (_offers.isEmpty)
                    GarraEmptyState(
                      title: 'Aún no hay ofertas',
                      message: 'Cuando un Negocio Crema verificado publique una promoción, la verás aquí.',
                      hint: '¿Cómo funciona? Los dueños verificados crean ofertas desde Mi negocio.',
                    )
                  else
                    ..._offers.map((o) {
                      final title = o.title;
                      final point = o.cremaPointName ?? '';
                      final desc = o.description;
                      final following = o.following;
                      final pointId = o.cremaPointId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: GarraSpacing.md),
                        child: GarraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: Theme.of(context).textTheme.titleMedium),
                              if (point.isNotEmpty)
                                Text(point, style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 6),
                              Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (pointId.isNotEmpty)
                                    TextButton(
                                      onPressed: () async {
                                        if (following) {
                                          await _service.unfollow(pointId);
                                        } else {
                                          await _service.follow(pointId);
                                        }
                                        await _load(nearby: _nearby);
                                      },
                                      child: Text(following ? 'Siguiendo' : 'Seguir'),
                                    ),
                                  TextButton(
                                    onPressed: () => Share.share(
                                      '$title — $point en Garra Digital',
                                    ),
                                    child: const Text('Compartir'),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push('/ruta-templo'),
                                    child: const Text('Mapa'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
