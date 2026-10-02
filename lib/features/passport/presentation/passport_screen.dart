import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_motion.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_brand_visual.dart';
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
import 'social_profile_links.dart';

class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passportAsync = ref.watch(myPassportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (passportAsync.asData?.value.viewerIsOwner == true) ...[
            TextButton(
              onPressed: () => context.push('/passport/edit'),
              child: const Text('Editar'),
            ),
            IconButton(
              tooltip: 'Configuración',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ],
      ),
      body: passportAsync.when(
        loading: () => const GarraPassportSkeleton(),
        error: (error, stackTrace) =>
            GarraErrorState(onRetry: () => ref.invalidate(myPassportProvider)),
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
          child: _ProfileHero(
            identity: identity,
            level: level,
            stats: stats,
            globalRank: passport.globalRank,
            numberFormat: numberFormat,
          ),
        ),
        const SizedBox(height: GarraSpacing.xxl),
        GarraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GarraLevelBadge(levelNumber: level.number, levelName: level.name),
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
                    color: context.garraColors.brandPrestige,
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
                  color: context.garraColors.textSecondary,
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
              Consumer(
                builder: (context, ref, _) {
                  final meId = currentFanIdOf(ref)?.trim() ?? '';
                  if (meId.isEmpty) return const SizedBox.shrink();
                  return _ProfileMenuTile(
                    key: const Key('passport-community-profile'),
                    icon: Icons.groups_2_outlined,
                    title: 'Mi perfil en la comunidad',
                    subtitle: 'Seguidores, seguidos y publicaciones',
                    onTap: () => context.push('/comunidad/u/$meId'),
                  );
                },
              ),
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
                    color: context.garraColors.brandPrestige,
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
          foregroundColor: context.garraColors.brandPrimary,
          borderColor: context.garraColors.brandPrimary,
        ),
        const SizedBox(height: GarraSpacing.xxl),
        Text(
          'Comunidad no oficial de hinchas cremas\n'
          'Hecho por hinchas, para hinchas\n\n'
          'Garra Digital es una comunidad independiente y no representa una aplicación oficial del club.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.garraColors.textSecondary,
            height: 1.45,
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
    if ((city == null || city.isEmpty) &&
        (country == null || country.isEmpty)) {
      return null;
    }
    if (city != null &&
        city.isNotEmpty &&
        country != null &&
        country.isNotEmpty) {
      return '$city · $country';
    }
    return city ?? country;
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.identity,
    required this.level,
    required this.stats,
    required this.globalRank,
    required this.numberFormat,
  });

  final PassportIdentity identity;
  final PassportLevel level;
  final PassportStats stats;
  final int? globalRank;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final location = _PassportBody._locationLine(identity);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            GarraAtmosphericHero(
              height: 164,
              assetPath: 'assets/visual/garra_match_hero.png',
              alignment: Alignment.topCenter,
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GarraCrest(size: 42, showGlow: true),
                  SizedBox(width: GarraSpacing.sm),
                  Expanded(
                    child: Text(
                      'COMUNIDAD NO OFICIAL\nDE HINCHAS CREMAS',
                      style: TextStyle(
                        color: Color(GarraColors.cream),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: -48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.background,
                  border: Border.all(color: colors.background, width: 5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: GarraAvatar(
                  displayName: identity.displayName,
                  avatarUrl: identity.avatarUrl,
                  size: 96,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 58),
        Text(
          identity.displayName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: GarraSpacing.xs),
        Text(
          '@${identity.username}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: GarraSpacing.sm),
        GarraLevelBadge(levelNumber: level.number, levelName: level.name),
        if (location != null || identity.supporterSinceYear != null) ...[
          const SizedBox(height: GarraSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: GarraSpacing.md,
            runSpacing: GarraSpacing.xs,
            children: [
              if (location != null)
                _IdentityDetail(icon: Icons.place_outlined, label: location),
              if (identity.supporterSinceYear != null)
                _IdentityDetail(
                  icon: Icons.favorite_outline,
                  label: 'Crema desde ${identity.supporterSinceYear}',
                ),
            ],
          ),
        ],
        if (identity.bio != null && identity.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: GarraSpacing.sm),
          Text(
            identity.bio!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        SocialProfileLinks(
          instagramUrl: identity.instagramUrl,
          tiktokUrl: identity.tiktokUrl,
          youtubeUrl: identity.youtubeUrl,
        ),
        const SizedBox(height: GarraSpacing.md),
        GarraSectionAtmosphere(
          padding: const EdgeInsets.symmetric(
            horizontal: GarraSpacing.sm,
            vertical: GarraSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: _HeroStat(
                  value: numberFormat.format(level.points),
                  label: 'Puntos',
                ),
              ),
              const _HeroStatDivider(),
              Expanded(
                child: _HeroStat(
                  value: numberFormat.format(stats.checkIns),
                  label: 'Check-ins',
                ),
              ),
              const _HeroStatDivider(),
              Expanded(
                child: _HeroStat(
                  value: globalRank == null ? '—' : '#$globalRank',
                  label: 'Ranking',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityDetail extends StatelessWidget {
  const _IdentityDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.garraColors.brandPrestige),
        const SizedBox(width: GarraSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GarraTypography.numeric(
              size: 22,
            ).copyWith(color: const Color(GarraColors.cream)),
          ),
        ),
        const SizedBox(height: GarraSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(GarraColors.creamMuted),
          ),
        ),
      ],
    );
  }
}

class _HeroStatDivider extends StatelessWidget {
  const _HeroStatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 38,
      child: VerticalDivider(color: Color(GarraColors.borderSubtle)),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    super.key,
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
          leading: Icon(icon, color: context.garraColors.brandPrestige),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Icon(
            Icons.chevron_right,
            color: context.garraColors.brandPrestige,
          ),
          onTap: onTap,
        ),
        if (showDivider) Divider(height: 1, color: context.garraColors.border),
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

    final members = NumberFormat.decimalPattern('es').format(clan!.memberCount);
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
                          color: context.garraColors.brandPrestige,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.garraColors.brandPrestige,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final passportSeasonProgressProvider =
    FutureProvider.autoDispose<SeasonProgressModel?>((ref) =>
        RetentionService().mySeasonProgress());

class _PassportSeasonSection extends ConsumerWidget {
  const _PassportSeasonSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(passportSeasonProgressProvider).asData?.value;
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
          Icon(
            Icons.admin_panel_settings_outlined,
            color: context.garraColors.brandPrestige,
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
          Icon(Icons.chevron_right, color: context.garraColors.brandPrestige),
        ],
      ),
    );
  }
}
