import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';

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
                  label: 'Negocios',
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
          const SizedBox(height: GarraSpacing.xl),
          if (_show(_ExploreFilter.events))
            _DestinationSection(
              icon: Icons.event_outlined,
              title: 'Eventos cercanos',
              subtitle: 'Quedadas y actividades de la hinchada',
              onTap: () => context.push('/eventos'),
            ),
          if (_show(_ExploreFilter.businesses))
            _DestinationSection(
              icon: Icons.map_outlined,
              title: 'Negocios cerca de ti',
              subtitle: 'Puntos Crema y lugares de la hinchada',
              onTap: () => context.push('/ruta-templo'),
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
              subtitle: 'Emprendimientos de la hinchada',
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
      child: GarraCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(GarraColors.garnetDeep),
                borderRadius: BorderRadius.circular(GarraRadius.md),
                border: Border.all(
                  color: const Color(GarraColors.gold).withValues(alpha: 0.35),
                ),
              ),
              child: Icon(icon, color: const Color(GarraColors.gold), size: 28),
            ),
            const SizedBox(width: GarraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: GarraSpacing.xs),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
          ],
        ),
      ),
    );
  }
}
