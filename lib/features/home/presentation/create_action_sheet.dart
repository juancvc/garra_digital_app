import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config_service.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';

/// V1 Crear intention selector — never jump straight into a form.
Future<void> showCreateActionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(GarraColors.surface),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _CreateActionSheet(),
  );
}

class _CreateActionSheet extends StatelessWidget {
  const _CreateActionSheet();

  @override
  Widget build(BuildContext context) {
    final cfg = appConfigService.current;
    final actions = <_CreateAction>[
      if (cfg.feature('community'))
        _CreateAction(
          title: 'Publicación',
          subtitle: 'Comparte lo que vive la crema',
          icon: Icons.edit_outlined,
          color: const Color(GarraColors.burgundy),
          onTap: () {
            Navigator.pop(context);
            context.push('/comunidad/compose');
          },
        ),
      if (cfg.feature('events'))
        _CreateAction(
          title: 'Evento',
          subtitle: 'Quedadas y actividades',
          icon: Icons.event_outlined,
          color: const Color(GarraColors.gold),
          onTap: () {
            Navigator.pop(context);
            context.push('/eventos/nuevo');
          },
        ),
      if (cfg.feature('marketplace'))
        _CreateAction(
          title: 'Emprendimiento',
          subtitle: 'Publica tu tienda en Marketplace',
          icon: Icons.storefront_outlined,
          color: const Color(GarraColors.surfaceRaised),
          onTap: () {
            Navigator.pop(context);
            context.push('/marketplace/seller');
          },
        ),
      if (cfg.feature('solidaria'))
        _CreateAction(
          title: 'Campaña Solidaria',
          subtitle: 'Ayuda a la comunidad',
          icon: Icons.volunteer_activism_outlined,
          color: const Color(GarraColors.surfaceRaised),
          onTap: () {
            Navigator.pop(context);
            context.push('/solidaria/nueva');
          },
        ),
      if (cfg.feature('community'))
        _CreateAction(
          title: 'Comunidad',
          subtitle: 'Crea un grupo de hinchas',
          icon: Icons.groups_outlined,
          color: const Color(GarraColors.surfaceRaised),
          onTap: () {
            Navigator.pop(context);
            context.push('/clans/create');
          },
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '¿Qué quieres crear?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: GarraSpacing.md),
            ...actions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                child: Material(
                  color: a.color,
                  borderRadius: BorderRadius.circular(GarraRadius.md),
                  child: InkWell(
                    onTap: a.onTap,
                    borderRadius: BorderRadius.circular(GarraRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(GarraSpacing.lg),
                      child: Row(
                        children: [
                          Icon(a.icon, color: const Color(GarraColors.cream)),
                          const SizedBox(width: GarraSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  a.subtitle,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(GarraColors.cream),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateAction {
  const _CreateAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
