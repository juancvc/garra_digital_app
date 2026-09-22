import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config_service.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_brand_visual.dart';

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
          color: const Color(GarraColors.success),
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
          color: const Color(GarraColors.burgundyDeep),
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
          color: const Color(GarraColors.burgundy),
          onTap: () {
            Navigator.pop(context);
            context.push('/clans/create');
          },
        ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.sm,
          GarraSpacing.lg,
          GarraSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(
                    GarraColors.creamMuted,
                  ).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(GarraRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: GarraSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GarraCrest(size: 46, showGlow: true),
                const SizedBox(width: GarraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GarraEditorialEyebrow(
                        label: 'Haz tribuna',
                        icon: Icons.bolt,
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      Text(
                        '¿Qué quieres crear?',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(GarraColors.cream),
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                      ),
                      Text(
                        'Elige una forma de mover a la comunidad.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(GarraColors.creamMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: GarraSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final useGrid = constraints.maxWidth >= 400;
                final tileWidth = useGrid
                    ? (constraints.maxWidth - GarraSpacing.sm) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: GarraSpacing.sm,
                  runSpacing: GarraSpacing.sm,
                  children: [
                    for (final action in actions)
                      SizedBox(
                        width: tileWidth,
                        child: _CreateActionTile(
                          action: action,
                          compact: useGrid,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateActionTile extends StatelessWidget {
  const _CreateActionTile({required this.action, required this.compact});

  final _CreateAction action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconColor = action.color == const Color(GarraColors.gold)
        ? const Color(GarraColors.burgundyDeep)
        : const Color(GarraColors.cream);
    return Material(
      color: const Color(GarraColors.surfaceRaised),
      borderRadius: BorderRadius.circular(GarraRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          action.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.md,
            GarraSpacing.md,
            GarraSpacing.sm,
            GarraSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 42 : 48,
                height: compact ? 42 : 48,
                decoration: BoxDecoration(
                  color: action.color,
                  borderRadius: BorderRadius.circular(GarraRadius.sm),
                ),
                child: Icon(action.icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(GarraColors.cream),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(GarraColors.creamMuted),
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact)
                const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
            ],
          ),
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
