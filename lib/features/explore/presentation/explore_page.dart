import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';

/// Hub for secondary product surfaces — not a settings dump.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.background),
      appBar: AppBar(
        title: const Text('Explorar Garra'),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/comunidad/buscar'),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          TextField(
            readOnly: true,
            onTap: () => context.push('/comunidad/buscar'),
            decoration: const InputDecoration(
              hintText: 'Buscar hinchas, comunidades…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: GarraSpacing.xl),
          Text(
            'Destinos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.md),
          _Destination(
            icon: Icons.groups_outlined,
            title: 'Comunidades Cremas',
            subtitle: 'Grupos de hinchas',
            onTap: () => context.push('/clans'),
          ),
          _Destination(
            icon: Icons.map_outlined,
            title: 'Puntos Crema',
            subtitle: 'Mapa y lugares',
            onTap: () => context.push('/ruta-templo'),
          ),
          _Destination(
            icon: Icons.storefront_outlined,
            title: 'Marketplace',
            subtitle: 'Emprendimientos cremas',
            onTap: () => context.push('/marketplace'),
          ),
          _Destination(
            icon: Icons.event_outlined,
            title: 'Eventos',
            subtitle: 'Quedadas y actividades',
            onTap: () => context.push('/eventos'),
          ),
          _Destination(
            icon: Icons.volunteer_activism_outlined,
            title: 'Garra Solidaria',
            subtitle: 'Campañas de ayuda',
            onTap: () => context.push('/solidaria'),
          ),
        ],
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
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
      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
      child: GarraCard(
        child: ListTile(
          leading: Icon(icon, color: const Color(GarraColors.cream)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
