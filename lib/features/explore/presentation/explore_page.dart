import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_brand_visual.dart';

enum _ExploreFilter { all, communities, events, businesses, marketplace }

/// Discovery hub for secondary product surfaces.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  _ExploreFilter _filter = _ExploreFilter.all;

  bool _show(_ExploreFilter section) =>
      _filter == _ExploreFilter.all || _filter == section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.background),
      appBar: AppBar(title: const Text('Explorar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.section,
        ),
        children: [
          GarraAtmosphericHero(
            height: 210,
            alignment: const Alignment(0.15, -0.25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GarraEditorialEyebrow(
                  label: 'Hecho por la hinchada',
                  icon: Icons.explore_outlined,
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  'Descubre dónde late\nla comunidad crema.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(GarraColors.cream),
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  'Planes, lugares y proyectos para vivir la pasión.',
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(GarraColors.creamMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          TextField(
            readOnly: true,
            onTap: () => context.push('/comunidad/buscar'),
            decoration: const InputDecoration(
              hintText: 'Buscar en Garra Digital…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todo',
                  selected: _filter == _ExploreFilter.all,
                  onTap: () => setState(() => _filter = _ExploreFilter.all),
                ),
                _FilterChip(
                  label: 'Comunidades',
                  selected: _filter == _ExploreFilter.communities,
                  onTap: () =>
                      setState(() => _filter = _ExploreFilter.communities),
                ),
                _FilterChip(
                  label: 'Eventos',
                  selected: _filter == _ExploreFilter.events,
                  onTap: () => setState(() => _filter = _ExploreFilter.events),
                ),
                _FilterChip(
                  label: 'Negocios Cremas',
                  selected: _filter == _ExploreFilter.businesses,
                  onTap: () =>
                      setState(() => _filter = _ExploreFilter.businesses),
                ),
                _FilterChip(
                  label: 'Marketplace',
                  selected: _filter == _ExploreFilter.marketplace,
                  onTap: () =>
                      setState(() => _filter = _ExploreFilter.marketplace),
                ),
              ],
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          Text(
            _filter == _ExploreFilter.all
                ? 'PARA VIVIR LA CREMA'
                : 'EXPLORA ESTA PASIÓN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(GarraColors.gold),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: GarraSpacing.md),
          if (_filter == _ExploreFilter.all) ...[
            const _DiscoveryPreviewGrid(),
            const SizedBox(height: GarraSpacing.lg),
            Text(
              'MÁS FORMAS DE CONECTAR',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(GarraColors.gold),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: GarraSpacing.md),
          ],
          if (_filter == _ExploreFilter.events)
            _DestinationSection(
              icon: Icons.event_outlined,
              title: 'Eventos cercanos',
              subtitle: 'Quedadas y actividades de la hinchada',
              onTap: () => context.push('/eventos'),
            ),
          if (_filter == _ExploreFilter.businesses)
            _DestinationSection(
              icon: Icons.map_outlined,
              title: 'Negocios Cremas',
              subtitle: 'Negocios registrados de la hinchada',
              onTap: () => context.push('/negocios'),
            ),
          if (_show(_ExploreFilter.communities))
            _DestinationSection(
              icon: Icons.groups_outlined,
              title: 'Comunidades',
              subtitle: 'Encuentra tu gente crema',
              onTap: () => context.push('/clans'),
            ),
          if (_show(_ExploreFilter.marketplace))
            _DestinationSection(
              icon: Icons.storefront_outlined,
              title: 'Marketplace',
              subtitle: 'Anuncios, productos y servicios',
              onTap: () => context.push('/marketplace'),
            ),
          if (_filter == _ExploreFilter.all) ...[
            _DestinationSection(
              icon: Icons.volunteer_activism_outlined,
              title: 'Garra Solidaria',
              subtitle: 'Campañas de ayuda entre cremas',
              onTap: () => context.push('/solidaria'),
            ),
            _DestinationSection(
              icon: Icons.card_giftcard_outlined,
              title: 'Beneficios',
              subtitle: 'Canjea tus Puntos Garra',
              onTap: () => context.push('/rewards'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoveryPreviewGrid extends StatelessWidget {
  const _DiscoveryPreviewGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('explore-preview-grid'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DiscoveryPreviewCard(
            icon: Icons.event_outlined,
            eyebrow: 'AGENDA',
            title: 'Eventos cercanos',
            imageAlignment: const Alignment(-0.65, -0.15),
            onTap: () => context.push('/eventos'),
          ),
        ),
        const SizedBox(width: GarraSpacing.md),
        Expanded(
          child: _DiscoveryPreviewCard(
            icon: Icons.map_outlined,
            eyebrow: 'NEGOCIOS',
            title: 'Negocios Cremas',
            imageAlignment: const Alignment(0.75, -0.2),
            onTap: () => context.push('/negocios'),
          ),
        ),
      ],
    );
  }
}

class _DiscoveryPreviewCard extends StatelessWidget {
  const _DiscoveryPreviewCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.imageAlignment,
    required this.onTap,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final Alignment imageAlignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(GarraColors.surface),
      borderRadius: BorderRadius.circular(GarraRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 176,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/visual/garra_match_hero.png',
                fit: BoxFit.cover,
                alignment: imageAlignment,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(GarraColors.burgundyDeep)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22171311), Color(0xF2171311)],
                    stops: [0.2, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(GarraSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        icon,
                        color: const Color(GarraColors.gold),
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(GarraColors.gold),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: GarraSpacing.xs),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(GarraColors.cream),
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: GarraSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(GarraColors.garnet),
        checkmarkColor: const Color(GarraColors.cream),
        labelStyle: TextStyle(
          color: selected
              ? const Color(GarraColors.cream)
              : const Color(GarraColors.textPrimary),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(
          color: selected
              ? const Color(GarraColors.gold)
              : const Color(GarraColors.surfaceRaised),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarraRadius.pill),
        ),
      ),
    );
  }
}

class _DestinationSection extends StatelessWidget {
  const _DestinationSection({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: Material(
        color: const Color(GarraColors.surface),
        borderRadius: BorderRadius.circular(GarraRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 94,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: 0,
                  width: 142,
                  top: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/visual/garra_match_hero.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.75, -0.3),
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(GarraColors.burgundyDeep),
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(GarraColors.surface),
                        Color(GarraColors.surface),
                        Color(0xB8171311),
                      ],
                      stops: [0, 0.57, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(GarraSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(GarraColors.burgundy),
                          borderRadius: BorderRadius.circular(GarraRadius.sm),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(GarraColors.cream),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: GarraSpacing.md),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: GarraSpacing.xs),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: Color(GarraColors.gold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
