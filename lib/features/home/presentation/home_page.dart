import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../clans/data/clan_models.dart';
import '../../community/presentation/widgets/garra_reaction_bar.dart';
import '../../matches/presentation/providers/matches_provider.dart';
import '../../missions/data/mission_models.dart';
import '../../missions/presentation/widgets/garra_streak_card.dart';
import '../../predictions/presentation/providers/prediction_provider.dart';
import '../../ranking/presentation/providers/ranking_provider.dart';
import '../../marketplace/widgets/garra_sponsored_card.dart';
import '../../rewards/data/reward_service.dart';
import '../../sponsors/data/sponsor_service.dart';
import '../../sponsors/presentation/providers/sponsor_provider.dart';
import '../data/home_models.dart';
import 'providers/home_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Garra Digital'),
        actions: [
          homeAsync.maybeWhen(
            data: (home) => _NotificationBell(
              unreadCount: home.notifications.unreadCount,
              onTap: () => context.push('/notifications'),
            ),
            orElse: () => IconButton(
              tooltip: 'Notificaciones',
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_none_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: homeAsync.when(
        loading: () => const GarraHomeSkeleton(),
        error: (error, stackTrace) => GarraErrorState(
          onRetry: () => ref.invalidate(homeProvider),
        ),
        data: (home) => RefreshIndicator(
          color: const Color(GarraColors.gold),
          onRefresh: () async => ref.invalidate(homeProvider),
          child: _HomeBody(home: home),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de Garra Digital?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(authServiceProvider).logout();
    ref.invalidate(currentUserProvider);
    ref.invalidate(homeProvider);
    ref.invalidate(upcomingMatchesProvider);
    ref.invalidate(myPredictionsProvider);
    ref.invalidate(rankingProvider);
    if (context.mounted) {
      context.go('/login');
    }
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
        child: const Icon(Icons.notifications_none_outlined),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.home});

  final HomeModel home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[
      _FanHeader(fan: home.fan),
      const SizedBox(height: GarraSpacing.lg),
    ];

    if (home.hasMatch) {
      children.add(_MatchHero(home: home));
      children.add(const SizedBox(height: GarraSpacing.lg));
    } else {
      children.add(const _NoMatchCard());
      children.add(const SizedBox(height: GarraSpacing.lg));
      children.add(_PointsRankCard(fan: home.fan));
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

    if (home.hasMatch) {
      children.add(
        _PollaCard(
          prediction: home.prediction,
          matchId: home.match!.id,
          mvpOpen: home.mvpOpen,
          mvpPollId: home.mvpPollId,
        ),
      );
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

    if (home.checkIn.showCheckInCta) {
      children.add(
        _CheckInCard(
          checkIn: home.checkIn,
          matchId: home.match?.id,
        ),
      );
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

    // MAX_COMMERCIAL_HOME_SURFACES = 1 (matchday sponsor > sponsored reward)
    final commercial = home.commercial;
    if (commercial != null) {
      children.add(_HomeCommercialSection(commercial: commercial));
      children.add(const SizedBox(height: GarraSpacing.lg));
    } else if (home.sponsored != null) {
      children.add(
        _HomeSponsoredSection(sponsored: home.sponsored!),
      );
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

    if (home.mission != null || home.streak != null) {
      children.add(
        _MissionStreakSection(
          mission: home.mission,
          streak: home.streak,
          matchId: home.match?.id,
        ),
      );
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

    children.add(_HomeClanSection(clan: home.clan));
    children.add(const SizedBox(height: GarraSpacing.lg));
    children.add(const _MarketplaceShortcut());
    children.add(const SizedBox(height: GarraSpacing.lg));
    children.add(const _RewardsShortcut());
    children.add(const SizedBox(height: GarraSpacing.lg));

    if (home.hasMatch) {
      children.add(_PointsRankCard(fan: home.fan));
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

    children.add(_CommunityPreview(community: home.community));
    children.add(const SizedBox(height: GarraSpacing.xxl));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        GarraSpacing.xxl,
      ),
      children: children,
    );
  }
}

class _FanHeader extends StatelessWidget {
  const _FanHeader({required this.fan});

  final HomeFanSummary fan;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir pasaporte de ${fan.displayName}',
      child: InkWell(
        onTap: () => context.push('/passport'),
        borderRadius: BorderRadius.circular(GarraRadius.lg),
        child: GarraCard(
          child: Row(
            children: [
              GarraAvatar(
                displayName: fan.displayName,
                avatarUrl: fan.avatarUrl,
                size: 56,
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fan.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: GarraSpacing.xs),
                    Text(
                      '@${fan.username}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: GarraSpacing.sm),
                    GarraLevelBadge(
                      levelNumber: fan.levelNumber,
                      levelName: fan.levelName,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(GarraColors.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchHero extends StatefulWidget {
  const _MatchHero({required this.home});

  final HomeModel home;

  @override
  State<_MatchHero> createState() => _MatchHeroState();
}

class _MatchHeroState extends State<_MatchHero> {
  Timer? _ticker;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final next = _computeRemaining();
      final crossed = _remaining.inSeconds > 0 && next.inSeconds <= 0;
      setState(() => _remaining = next);
      if (crossed) {
        // Crossing kickoff: refresh server authority for matchday state.
        final container = ProviderScope.containerOf(context, listen: false);
        container.invalidate(homeProvider);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _computeRemaining() {
    final kickoff = widget.home.match!.matchDateTime.toLocal();
    return kickoff.difference(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    final match = home.match!;
    final dateLabel = DateFormat('EEE d MMM · HH:mm').format(
      match.matchDateTime.toLocal(),
    );

    String headline;
    String? liveBadge;
    if (home.isLive) {
      headline = 'EN VIVO';
      liveBadge = 'LIVE';
    } else if (home.isMatchday) {
      headline = 'Hoy juega la U';
    } else if (home.isFinished) {
      headline = 'Partido finalizado';
    } else {
      headline = 'Próximo partido';
    }

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headline,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(GarraColors.gold),
                        letterSpacing: 1.1,
                      ),
                ),
              ),
              if (liveBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GarraSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(GarraColors.garnet),
                    borderRadius: BorderRadius.circular(GarraRadius.sm),
                  ),
                  child: Text(
                    liveBadge,
                    style: const TextStyle(
                      color: Color(GarraColors.cream),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: GarraSpacing.md),
          Row(
            children: [
              Expanded(child: _TeamBlock(name: match.homeTeam)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.sm),
                child: home.isLive || home.isFinished
                    ? Text(
                        '${match.homeScore ?? '-'} : ${match.awayScore ?? '-'}',
                        style: GarraTypography.numeric(size: 28),
                      )
                    : Text(
                        'VS',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(GarraColors.gold),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
              ),
              Expanded(child: _TeamBlock(name: match.awayTeam, alignEnd: true)),
            ],
          ),
          const SizedBox(height: GarraSpacing.md),
          Text(
            match.competition,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: GarraSpacing.xs),
          Text(
            '${match.stadium} · $dateLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (home.isUpcoming || home.isMatchday) ...[
            const SizedBox(height: GarraSpacing.md),
            Text(
              _countdownLabel(_remaining),
              style: GarraTypography.numeric(size: 20),
            ),
          ],
          if (home.isLive || home.isMatchday) ...[
            const SizedBox(height: GarraSpacing.lg),
            GarraPrimaryButton(
              label: home.isLive ? 'Entrar al partido' : 'Entrar al Matchday',
              onPressed: () => context.push('/matchday/${match.id}/polls'),
            ),
          ],
          if (home.isFinished) ...[
            const SizedBox(height: GarraSpacing.lg),
            GarraSecondaryButton(
              label: 'Ver encuestas',
              onPressed: () => context.push('/matchday/${match.id}/polls'),
            ),
          ],
        ],
      ),
    );
  }

  String _countdownLabel(Duration remaining) {
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return 'Kickoff';
    }
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    if (days > 0) {
      return 'Faltan ${days}d ${hours.toString().padLeft(2, '0')}h';
    }
    if (remaining.inHours > 0) {
      return 'Faltan ${hours}h ${minutes.toString().padLeft(2, '0')} min';
    }
    return 'Faltan $minutes min';
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({required this.name, this.alignEnd = false});

  final String name;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(GarraColors.surfaceRaised),
            borderRadius: BorderRadius.circular(GarraRadius.md),
            border: Border.all(color: const Color(GarraColors.borderSubtle)),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Color(GarraColors.cream),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: GarraSpacing.sm),
        Text(
          name,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard();

  @override
  Widget build(BuildContext context) {
    return const GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sin partido cercano',
            style: TextStyle(
              color: Color(GarraColors.cream),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          SizedBox(height: GarraSpacing.sm),
          Text(
            'Cuando la U tenga fecha, el Matchday aparecerá aquí.',
            style: TextStyle(color: Color(GarraColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _PointsRankCard extends StatelessWidget {
  const _PointsRankCard({required this.fan});

  final HomeFanSummary fan;

  @override
  Widget build(BuildContext context) {
    final points = NumberFormat('#,###').format(fan.points);
    return GarraCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$points Puntos Garra',
                  style: GarraTypography.numeric(size: 22),
                ),
                if (fan.globalRank != null) ...[
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    '#${fan.globalRank} en Garra Digital',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(GarraColors.gold),
                        ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/rewards'),
            child: const Text('Beneficios'),
          ),
        ],
      ),
    );
  }
}

class _PollaCard extends StatelessWidget {
  const _PollaCard({
    required this.prediction,
    required this.matchId,
    required this.mvpOpen,
    this.mvpPollId,
  });

  final HomePrediction prediction;
  final String matchId;
  final bool mvpOpen;
  final String? mvpPollId;

  @override
  Widget build(BuildContext context) {
    final (subtitle, cta) = switch (prediction.state) {
      'PREDICTED' => (
          prediction.predictedHomeScore != null
              ? 'Ya jugaste · ${prediction.predictedHomeScore}-${prediction.predictedAwayScore}'
              : 'Ya jugaste',
          'Ver mi predicción',
        ),
      'LOCKED' => (
          prediction.predictedHomeScore != null
              ? 'La Polla cerró · ${prediction.predictedHomeScore}-${prediction.predictedAwayScore}'
              : 'La Polla cerró',
          'Ver La Polla',
        ),
      'SCORED' => (
          prediction.pointsEarned != null
              ? (prediction.pointsEarned! > 0
                  ? 'Ganaste ${prediction.pointsEarned} pts'
                  : 'Resultado disponible')
              : 'Resultado disponible',
          'Ver resultado',
        ),
      _ => (
          'Haz tu predicción',
          'Hacer predicción',
        ),
    };

    final pollaRoute = '/polla/$matchId';
    final mvpRoute = '/matchday/$matchId/polls';

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GarraSectionHeader(
            title: 'La Polla',
            subtitle: 'Predicción del partido',
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          if (prediction.firstScorer != null &&
              prediction.firstScorer!.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.xs),
            Text(
              'Primer goleador: ${prediction.firstScorer}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: GarraSpacing.md),
          GarraPrimaryButton(
            label: cta,
            onPressed: () => context.push(pollaRoute),
          ),
          if (mvpOpen) ...[
            const SizedBox(height: GarraSpacing.sm),
            GarraSecondaryButton(
              label: 'Vota por el MVP',
              onPressed: () => context.push(mvpRoute),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.checkIn,
    this.matchId,
  });

  final HomeCheckIn checkIn;
  final String? matchId;

  @override
  Widget build(BuildContext context) {
    final route = matchId != null && matchId!.isNotEmpty
        ? '/mapa-crema?matchId=$matchId'
        : '/mapa-crema';

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GarraSectionHeader(
            title: 'Check-in',
            subtitle: 'Presencia crema en el mapa',
          ),
          const SizedBox(height: GarraSpacing.md),
          GarraSecondaryButton(
            label: checkIn.ctaLabel ?? 'Ir al mapa',
            onPressed: () => context.push(route),
          ),
        ],
      ),
    );
  }
}

class _HomeCommercialSection extends ConsumerWidget {
  const _HomeCommercialSection({required this.commercial});

  final HomeCommercialCard commercial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (commercial.isSponsoredReward) {
      return GarraCard(
        onTap: () {
          final slug = commercial.rewardSlug;
          if (slug != null && slug.isNotEmpty) {
            if (commercial.rewardOfferId != null) {
              unawaited(
                RewardService().trackOpen(
                  commercial.rewardOfferId!,
                  activationId: commercial.activationId,
                ),
              );
            }
            context.push('/rewards/$slug');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              commercial.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(GarraColors.gold),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: GarraSpacing.sm),
            Text(
              commercial.headline,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (commercial.body != null && commercial.body!.isNotEmpty) ...[
              const SizedBox(height: GarraSpacing.xs),
              Text(
                commercial.body!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (commercial.pointsCost != null) ...[
              const SizedBox(height: GarraSpacing.sm),
              Text(
                '${commercial.pointsCost} Puntos Garra',
                style: GarraTypography.numeric(size: 16),
              ),
            ],
          ],
        ),
      );
    }

    final card = SponsoredCard(
      activationId: commercial.activationId,
      campaignId: commercial.campaignId,
      sponsorName: commercial.sponsorName,
      sponsorSlug: commercial.sponsorSlug,
      logoUrl: commercial.logoUrl,
      headline: commercial.headline,
      body: commercial.body,
      ctaLabel: commercial.ctaLabel,
      ctaUrl: commercial.ctaUrl,
      label: commercial.label,
    );
    return GarraSponsoredCard(
      card: card,
      onImpression: () {
        unawaited(
          ref
              .read(sponsorServiceProvider)
              .trackImpression(commercial.activationId),
        );
      },
      onOpen: () {
        unawaited(
          ref.read(sponsorServiceProvider).trackOpen(commercial.activationId),
        );
      },
    );
  }
}

class _HomeSponsoredSection extends ConsumerWidget {
  const _HomeSponsoredSection({required this.sponsored});

  final HomeSponsoredCard sponsored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = SponsoredCard(
      activationId: sponsored.activationId,
      campaignId: sponsored.campaignId,
      sponsorName: sponsored.sponsorName,
      sponsorSlug: sponsored.sponsorSlug,
      logoUrl: sponsored.logoUrl,
      headline: sponsored.headline,
      body: sponsored.body,
      ctaLabel: sponsored.ctaLabel,
      ctaUrl: sponsored.ctaUrl,
      label: sponsored.label,
    );
    return GarraSponsoredCard(
      card: card,
      onImpression: () {
        unawaited(
          ref
              .read(sponsorServiceProvider)
              .trackImpression(sponsored.activationId),
        );
      },
      onOpen: () {
        unawaited(
          ref.read(sponsorServiceProvider).trackOpen(sponsored.activationId),
        );
      },
    );
  }
}

class _MissionStreakSection extends StatelessWidget {
  const _MissionStreakSection({
    this.mission,
    this.streak,
    this.matchId,
  });

  final HomeMissionSummary? mission;
  final HomeStreakSummary? streak;
  final String? matchId;

  @override
  Widget build(BuildContext context) {
    final missionsRoute = matchId != null && matchId!.isNotEmpty
        ? '/missions?matchId=$matchId'
        : '/missions';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mission != null) ...[
          GarraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission!.isSponsored
                      ? (mission!.sponsorLabel ??
                          'Patrocinado por ${mission!.sponsorName ?? 'sponsor'}')
                      : 'Misión',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(GarraColors.gold),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  mission!.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: GarraSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: GarraProgressBar(
                        progress: mission!.progressFraction,
                      ),
                    ),
                    const SizedBox(width: GarraSpacing.md),
                    Text(
                      '${mission!.completedSteps}/${mission!.totalSteps}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: GarraSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(missionsRoute),
                    child: const Text('Ver misión'),
                  ),
                ),
              ],
            ),
          ),
          if (streak != null) const SizedBox(height: GarraSpacing.md),
        ],
        if (streak != null)
          GarraStreakCard(
            streak: StreakSummary(
              current: streak!.current,
              best: streak!.best,
            ),
            compact: true,
          ),
      ],
    );
  }
}

class _HomeClanSection extends StatelessWidget {
  const _HomeClanSection({this.clan});

  final HomeClanSummary? clan;

  @override
  Widget build(BuildContext context) {
    if (clan == null) {
      return GarraCard(
        onTap: () => context.push('/clans'),
        child: Row(
          children: [
            const Icon(Icons.groups_2_outlined, color: Color(GarraColors.gold)),
            const SizedBox(width: GarraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encuentra tu comunidad',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    'Descubre clanes crema cerca de ti',
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

    final members =
        NumberFormat.decimalPattern('es').format(clan!.memberCount);
    return GarraCard(
      onTap: () => context.push('/clans/${clan!.slug}'),
      child: Row(
        children: [
          GarraAvatar(
            displayName: clan!.name,
            avatarUrl: clan!.logoUrl,
            size: 44,
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clan!.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  [
                    '$members miembros',
                    if (clan!.role != null)
                      ClanRoleLabels.label(clan!.role),
                    if (clan!.currentYearRank != null)
                      '#${clan!.currentYearRank} Polla',
                    if (clan!.currentYearPollaPoints != null)
                      '${clan!.currentYearPollaPoints} pts',
                  ].join(' · '),
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

class _MarketplaceShortcut extends StatelessWidget {
  const _MarketplaceShortcut();

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      onTap: () => context.push('/marketplace'),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: Color(GarraColors.gold)),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marketplace Crema',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  'Descubre emprendimientos de la hinchada',
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

class _RewardsShortcut extends StatelessWidget {
  const _RewardsShortcut();

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      onTap: () => context.push('/rewards'),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_outlined, color: Color(GarraColors.gold)),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beneficios',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  'Canjea Puntos Garra por beneficios reales',
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

class _CommunityPreview extends StatelessWidget {
  const _CommunityPreview({required this.community});

  final HomeCommunityPreview community;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: GarraSectionHeader(
                title: 'Tribuna Crema',
                subtitle: 'Comunidad',
              ),
            ),
            TextButton(
              onPressed: () => context.push('/muro-crema'),
              child: const Text('Ver comunidad'),
            ),
          ],
        ),
        const SizedBox(height: GarraSpacing.sm),
        if (community.posts.isEmpty)
          const GarraCard(
            child: Text(
              'Aún no hay publicaciones para este contexto.',
              style: TextStyle(color: Color(GarraColors.textSecondary)),
            ),
          )
        else
          ...community.posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
              child: GarraCard(
                onTap: () => context.push('/muro-crema/posts/${post.id}'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GarraAvatar(displayName: post.displayName, size: 40),
                    const SizedBox(width: GarraSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${post.username}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: GarraSpacing.xs),
                          Text(
                            post.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: GarraSpacing.xs),
                          Text(
                            [
                              if (post.locationTag != null) post.locationTag!,
                              _relativeTime(post.createdAt),
                            ].join(' · '),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: GarraSpacing.sm),
                          GarraReactionBar(
                            reactionSummary: post.reactionSummary,
                            reactionCount: post.reactionCount,
                            commentCount: post.commentCount,
                            myReaction: post.myReaction,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }
}
