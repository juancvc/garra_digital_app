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
import '../../matches/presentation/providers/matches_provider.dart';
import '../../predictions/presentation/providers/prediction_provider.dart';
import '../../ranking/presentation/providers/ranking_provider.dart';
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
      children.add(_PollaCard(prediction: home.prediction));
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

    if (home.checkIn.showCheckInCta) {
      children.add(_CheckInCard(checkIn: home.checkIn));
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

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
              onPressed: () => context.push('/muro-crema'),
            ),
          ],
          if (home.isFinished) ...[
            const SizedBox(height: GarraSpacing.lg),
            GarraSecondaryButton(
              label: 'Ver comunidad',
              onPressed: () => context.push('/muro-crema'),
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
            onPressed: () => context.push('/passport'),
            child: const Text('Pasaporte'),
          ),
        ],
      ),
    );
  }
}

class _PollaCard extends StatelessWidget {
  const _PollaCard({required this.prediction});

  final HomePrediction prediction;

  @override
  Widget build(BuildContext context) {
    final (subtitle, cta) = switch (prediction.state) {
      'PREDICTED' => (
          prediction.predictedHomeScore != null
              ? 'Tu predicción: ${prediction.predictedHomeScore}-${prediction.predictedAwayScore}'
              : 'Ya registraste tu predicción',
          'Ver mi predicción',
        ),
      'LOCKED' => (
          prediction.predictedHomeScore != null
              ? 'Predicción cerrada: ${prediction.predictedHomeScore}-${prediction.predictedAwayScore}'
              : 'Predicciones cerradas',
          'Ver La Polla',
        ),
      'SCORED' => (
          prediction.pointsEarned != null
              ? 'Resultado · +${prediction.pointsEarned} pts'
              : 'Resultado disponible',
          'Ver resultado',
        ),
      _ => (
          'Aún no has predicho este partido',
          'Hacer predicción',
        ),
    };

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GarraSectionHeader(
            title: 'La Polla',
            subtitle: 'Tu predicción',
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: GarraSpacing.md),
          GarraPrimaryButton(
            label: cta,
            onPressed: () => context.push('/polla'),
          ),
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.checkIn});

  final HomeCheckIn checkIn;

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => context.push('/mapa-crema'),
          ),
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
