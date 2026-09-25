import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../data/crema_point_model.dart';
import '../data/location_service.dart';

/// Registered crema businesses. Separate from Marketplace listings and from
/// the stadium route.
class NegociosCremasPage extends StatelessWidget {
  const NegociosCremasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
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
            title: 'Mi negocio',
            subtitle: 'Registra o administra tu negocio',
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
      color: const Color(GarraColors.surface),
      child: ListTile(
        leading: Icon(icon, color: const Color(GarraColors.gold)),
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

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
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
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: !_verifiedOnly,
                  onSelected: (_) => setState(() => _verifiedOnly = false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Verificados'),
                  selected: _verifiedOnly,
                  onSelected: (_) => setState(() => _verifiedOnly = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final point = visible[index];
                      return ListTile(
                        title: Text(point.name),
                        subtitle: Text(point.address),
                        onTap: () => context.push('/negocios/${point.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class NegocioCremaDetailPage extends StatefulWidget {
  const NegocioCremaDetailPage({super.key, required this.idOrSlug});

  final String idOrSlug;

  @override
  State<NegocioCremaDetailPage> createState() => _NegocioCremaDetailPageState();
}

class _NegocioCremaDetailPageState extends State<NegocioCremaDetailPage> {
  final _service = LocationService();
  CremaPointModel? _point;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      if (!mounted) return;
      setState(() {
        _point = match;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: Text(point?.name ?? 'Negocio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : point == null
          ? const Center(child: Text('No encontramos este negocio'))
          : ListView(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              children: [
                Text(
                  point.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(point.address),
                if ((point.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(point.description!),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.push('/negocios/mapa'),
                  child: const Text('Ver en el mapa'),
                ),
              ],
            ),
    );
  }
}
