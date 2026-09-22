import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_motion.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../auth/data/auth_service.dart';
import '../../clans/data/clan_models.dart';
import '../../retention/data/retention_models.dart';
import '../../retention/data/retention_service.dart';
import '../../retention/presentation/season_progress_page.dart';
import '../data/passport_models.dart';
import 'providers/passport_provider.dart';

class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passportAsync = ref.watch(myPassportProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (passportAsync.asData?.value.viewerIsOwner == true)
            TextButton(
              onPressed: () => context.push('/passport/edit'),
              child: const Text('Editar'),
            ),
        ],
      ),
      body: passportAsync.when(
        loading: () => const GarraPassportSkeleton(),
        error: (error, stackTrace) => GarraErrorState(
          onRetry: () => ref.invalidate(myPassportProvider),
        ),
        data: (PassportModel passport) => _PassportBody(passport: passport),
      ),
    );
  }
}

class _PassportBody extends StatelessWidget {
  const _PassportBody({required this.passport});

  final PassportModel passport;

  @override
  Widget build(BuildContext context) {
    final identity = passport.identity;
    final level = passport.level;
    final stats = passport.stats;
    final numberFormat = NumberFormat.decimalPattern('es');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        GarraSpacing.section,
      ),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: GarraMotion.normal,
          curve: GarraMotion.entrance,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Column(
            children: [
              GarraAvatar(
                displayName: identity.displayName,
                avatarUrl: identity.avatarUrl,
                size: 96,
              ),
              const SizedBox(height: GarraSpacing.lg),
              Text(
                identity.displayName,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: GarraSpacing.xs),
              Text(
                '@${identity.username}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_locationLine(identity) != null) ...[
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  _locationLine(identity)!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
              if (identity.supporterSinceYear != null) ...[
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  'Crema desde ${identity.supporterSinceYear}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                ),
              ],
              if (identity.bio != null && identity.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.md),
                Text(
                  identity.bio!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.xxl),
        GarraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GarraLevelBadge(
                levelNumber: level.number,
                levelName: level.name,
              ),
              const SizedBox(height: GarraSpacing.lg),
              Text(
                '${numberFormat.format(level.points)} Puntos Garra',
                style: GarraTypography.numeric(size: 28),
              ),
              const SizedBox(height: GarraSpacing.md),
              GarraProgressBar(progress: level.progressFraction),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                level.nextLevelPoints == null
                    ? 'Nivel máximo alcanzado'
                    : '${numberFormat.format(level.pointsToNextLevel)} pts para el siguiente nivel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (passport.globalRank != null) ...[
                const SizedBox(height: GarraSpacing.md),
                Text(
                  'Ranking global #${passport.globalRank}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.lg),
        GarraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GarraSectionHeader(title: 'Tu actividad'),
              const SizedBox(height: GarraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: GarraStat(
                      label: 'Check-ins',
                      value: numberFormat.format(stats.checkIns),
                    ),
                  ),
                  Expanded(
                    child: GarraStat(
                      label: 'Predicciones',
                      value: numberFormat.format(stats.predictions),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: GarraStat(
                      label: 'Puntos Polla',
                      value: numberFormat.format(stats.predictionPoints),
                    ),
                  ),
                  Expanded(
                    child: GarraStat(
                      label: 'Publicaciones',
                      value: numberFormat.format(stats.posts),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: GarraStat(
                      label: 'Racha Garra',
                      value: numberFormat.format(stats.streakCurrent),
                    ),
                  ),
                  Expanded(
                    child: GarraStat(
                      label: 'Mejor racha',
                      value: numberFormat.format(stats.streakBest),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                'Participación en fechas',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(GarraColors.textSecondary),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.lg),
        const _PassportSeasonSection(),
        const SizedBox(height: GarraSpacing.lg),
        _PassportClanSection(clan: passport.primaryClan),
        const SizedBox(height: GarraSpacing.lg),
        GarraCard(
          child: Column(
            children: [
              _ProfileMenuTile(
                icon: Icons.auto_stories_outlined,
                title: 'Mi contenido',
                subtitle: 'Tu línea de tiempo crema',
                onTap: () => context.push('/history'),
              ),
              _ProfileMenuTile(
                icon: Icons.bookmark_outline,
                title: 'Guardados',
                subtitle: 'Publicaciones que guardaste',
                onTap: () => context.push('/comunidad/guardados'),
              ),
              _ProfileMenuTile(
                icon: Icons.groups_outlined,
                title: 'Mis comunidades',
                subtitle: 'Tus grupos cremas',
                onTap: () => context.push('/clans'),
              ),
              _ProfileMenuTile(
                icon: Icons.event_outlined,
                title: 'Mis eventos',
                subtitle: 'Encuentros y actividades',
                onTap: () => context.push('/eventos'),
              ),
              _ProfileMenuTile(
                icon: Icons.storefront_outlined,
                title: 'Mis emprendimientos',
                subtitle: 'Tu tienda en Marketplace',
                onTap: () => context.push('/marketplace/seller'),
              ),
              _ProfileMenuTile(
                icon: Icons.card_giftcard_outlined,
                title: 'Mis puntos Garra',
                subtitle: 'Canjea beneficios',
                onTap: () => context.push('/rewards'),
              ),
              _ProfileMenuTile(
                icon: Icons.emoji_events_outlined,
                title: 'Mis logros',
                subtitle: 'Hitos desbloqueados',
                onTap: () => context.push('/logros'),
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.lg),
        if (passport.currentYearSummary != null) ...[
          GarraCard(
            onTap: () => context.push('/history'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi Historia Crema',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  'Mi Año Crema ${passport.currentYearSummary!.year}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
        ],
        const _AdminCenterEntry(),
        const SizedBox(height: GarraSpacing.lg),
        GarraCard(
          onTap: () => context.push('/settings'),
          child: _ProfileMenuTile(
            icon: Icons.settings_outlined,
            title: 'Configuración',
            subtitle: 'Ajustes, privacidad y cuenta',
            showDivider: false,
            onTap: () => context.push('/settings'),
          ),
        ),
        const SizedBox(height: GarraSpacing.lg),
        GarraSecondaryButton(
          label: 'Cerrar sesión',
          onPressed: () => _confirmLogout(context),
          foregroundColor: const Color(GarraColors.burgundy),
          borderColor: const Color(GarraColors.burgundy),
        ),
        const SizedBox(height: GarraSpacing.xxl),
        Text(
          'Garra Digital es una comunidad independiente creada por hinchas y no representa una aplicación oficial del club.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(GarraColors.creamMuted),
              ),
        ),
      ],
    );
  }

  static Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().logout();
    if (context.mounted) context.go('/login');
  }

  static String? _locationLine(PassportIdentity identity) {
    final city = identity.city?.trim();
    final country = identity.countryCode?.trim();
    if ((city == null || city.isEmpty) && (country == null || country.isEmpty)) {
      return null;
    }
    if (city != null && city.isNotEmpty && country != null && country.isNotEmpty) {
      return '$city · $country';
    }
    return city ?? country;
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: const Color(GarraColors.gold)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(
            Icons.chevron_right,
            color: Color(GarraColors.gold),
          ),
          onTap: onTap,
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(GarraColors.surfaceRaised)),
      ],
    );
  }
}

class _PassportClanSection extends StatelessWidget {
  const _PassportClanSection({this.clan});

  final PassportClanSummary? clan;

  @override
  Widget build(BuildContext context) {
    if (clan == null) {
      return GarraCard(
        onTap: () => context.push('/clans'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GarraSectionHeader(
              title: 'Mi Clan',
              subtitle: 'Tu comunidad en Garra Digital',
            ),
            const SizedBox(height: GarraSpacing.md),
            Text(
              'Encuentra tu clan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: GarraSpacing.xs),
            Text(
              'Únete a una comunidad crema y comparte la pasión.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final members =
        NumberFormat.decimalPattern('es').format(clan!.memberCount);
    return GarraCard(
      onTap: () => context.push('/clans/${clan!.slug}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GarraSectionHeader(title: 'Mi Clan'),
          const SizedBox(height: GarraSpacing.md),
          Row(
            children: [
              GarraAvatar(
                displayName: clan!.name,
                avatarUrl: clan!.logoUrl,
                size: 52,
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clan!.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: GarraSpacing.xs),
                    Text(
                      '$members miembros',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (clan!.role != null) ...[
                      const SizedBox(height: GarraSpacing.xs),
                      Text(
                        ClanRoleLabels.label(clan!.role),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(GarraColors.gold),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PassportSeasonSection extends StatefulWidget {
  const _PassportSeasonSection();

  @override
  State<_PassportSeasonSection> createState() => _PassportSeasonSectionState();
}

class _PassportSeasonSectionState extends State<_PassportSeasonSection> {
  SeasonProgressModel? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final progress = await RetentionService().mySeasonProgress();
      if (!mounted) return;
      setState(() => _progress = progress);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress == null) return const SizedBox.shrink();
    return SeasonHeroCard(
      progress: progress,
      onOpen: () => context.push('/passport/temporada'),
    );
  }
}

class _AdminCenterEntry extends StatefulWidget {
  const _AdminCenterEntry();

  @override
  State<_AdminCenterEntry> createState() => _AdminCenterEntryState();
}

class _AdminCenterEntryState extends State<_AdminCenterEntry> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final me = await AuthService().me();
      if (!mounted) return;
      setState(() => _show = me?.isAdmin == true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return GarraCard(
      onTap: () => context.push('/admin'),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: Color(GarraColors.gold),
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centro Garra',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  'Moderación y operación',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
        ],
      ),
    );
  }
}
