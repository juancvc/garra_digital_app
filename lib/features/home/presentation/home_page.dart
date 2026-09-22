import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_brand_visual.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../marketplace/widgets/garra_sponsored_card.dart';
import '../../missions/data/mission_models.dart';
import '../../missions/presentation/widgets/garra_streak_card.dart';
import '../../rewards/data/reward_service.dart';
import '../../sponsors/data/sponsor_service.dart';
import '../../sponsors/presentation/providers/sponsor_provider.dart';
import '../data/home_models.dart';
import 'providers/home_provider.dart';
import 'social_feed_tab.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: GarraBrandLockup(compact: true, crestSize: 30),
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/comunidad/buscar'),
            icon: const Icon(Icons.search),
          ),
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
        ],
      ),
      body: homeAsync.when(
        loading: () => const GarraHomeSkeleton(),
        error: (error, stackTrace) =>
            GarraErrorState(onRetry: () => ref.invalidate(homeProvider)),
        data: (home) => _HomeBody(home: home),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount, required this.onTap});

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

enum _HomeFeedTab { forYou, following, match }

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody({required this.home});

  final HomeModel home;

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  late _HomeFeedTab _tab;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _tab = _defaultTab(widget.home);
  }

  @override
  void didUpdateWidget(covariant _HomeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_manual) {
      _tab = _defaultTab(widget.home);
    }
  }

  static _HomeFeedTab _defaultTab(HomeModel home) {
    return _HomeFeedTab.forYou;
  }

  bool get _showCompactMatch {
    final home = widget.home;
    return home.hasMatch && (home.isLive || home.isUpcoming || home.isMatchday);
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    final forYouInserts = <Widget>[
      if (_showCompactMatch)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.lg,
            0,
            GarraSpacing.lg,
            GarraSpacing.md,
          ),
          child: _CompactMatchInsert(
            home: home,
            onOpenMatch: () => setState(() {
              _manual = true;
              _tab = _HomeFeedTab.match;
            }),
          ),
        ),
      if (_hasContextualInsert(home))
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.lg,
            0,
            GarraSpacing.lg,
            GarraSpacing.md,
          ),
          child: _HomeContextualInsert(home: home),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.lg,
            GarraSpacing.md,
            GarraSpacing.lg,
            GarraSpacing.sm,
          ),
          child: _FeedTabChips(
            tab: _tab,
            onChanged: (t) => setState(() {
              _manual = true;
              _tab = t;
            }),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _HomeFeedTab.match => RefreshIndicator(
              color: const Color(GarraColors.burgundy),
              onRefresh: () async => ref.invalidate(homeProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  GarraSpacing.lg,
                  GarraSpacing.sm,
                  GarraSpacing.lg,
                  GarraSpacing.xxl,
                ),
                children: _matchChildren(context, home),
              ),
            ),
            _HomeFeedTab.forYou => SocialFeedTab(
              key: const ValueKey('FOR_YOU'),
              mode: 'FOR_YOU',
              contextualInserts: forYouInserts,
            ),
            _HomeFeedTab.following => const SocialFeedTab(
              key: ValueKey('FOLLOWING'),
              mode: 'FOLLOWING',
            ),
          },
        ),
      ],
    );
  }

  bool _hasContextualInsert(HomeModel home) {
    return home.clan != null ||
        home.community.posts.isNotEmpty ||
        home.commercial != null ||
        home.sponsored != null;
  }

  List<Widget> _matchChildren(BuildContext context, HomeModel home) {
    final children = <Widget>[];
    if (home.hasMatch) {
      children.add(_MatchHero(home: home));
      children.add(const SizedBox(height: GarraSpacing.lg));
      children.add(
        _PulsoCremaCard(
          prediction: home.prediction,
          matchId: home.match!.id,
          mvpOpen: home.mvpOpen,
        ),
      );
      children.add(const SizedBox(height: GarraSpacing.lg));
    } else {
      children.add(const _NoMatchCard());
      children.add(const SizedBox(height: GarraSpacing.lg));
    }

    if (home.checkIn.showCheckInCta) {
      children.add(
        _CheckInCard(checkIn: home.checkIn, matchId: home.match?.id),
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

    final commercial = home.commercial;
    if (commercial != null) {
      children.add(_HomeCommercialSection(commercial: commercial));
    } else if (home.sponsored != null) {
      children.add(_HomeSponsoredSection(sponsored: home.sponsored!));
    }
    return children;
  }
}

class _HomeContextualInsert extends StatelessWidget {
  const _HomeContextualInsert({required this.home});

  final HomeModel home;

  @override
  Widget build(BuildContext context) {
    final clan = home.clan;
    final communityPost = home.community.posts.firstOrNull;
    final commercial = home.commercial;
    final sponsored = home.sponsored;

    String eyebrow;
    String title;
    String detail;
    IconData icon;
    VoidCallback onTap;

    if (clan != null) {
      eyebrow = 'TU COMUNIDAD';
      title = clan.name;
      detail = '${clan.memberCount} miembros';
      icon = Icons.groups_outlined;
      onTap = () => context.push('/clans/${clan.slug}');
    } else if (communityPost != null) {
      eyebrow = 'EN LA TRIBUNA';
      title = communityPost.displayName;
      detail = communityPost.content;
      icon = Icons.forum_outlined;
      onTap = () => context.push('/comunidad');
    } else {
      final card = commercial;
      eyebrow = card?.label ?? sponsored!.label;
      title = card?.headline ?? sponsored!.headline;
      detail = card?.body ?? sponsored!.body ?? '';
      icon = Icons.workspace_premium_outlined;
      onTap = () {
        final rewardSlug = card?.rewardSlug;
        if (rewardSlug != null && rewardSlug.isNotEmpty) {
          context.push('/rewards/$rewardSlug');
        }
      };
    }

    return Semantics(
      button: true,
      label: '$eyebrow, $title',
      child: Material(
        key: const ValueKey('home-contextual-insert'),
        color: const Color(GarraColors.surface),
        borderRadius: BorderRadius.circular(GarraRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(GarraSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(
                      GarraColors.burgundy,
                    ).withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(GarraRadius.sm),
                  ),
                  child: Icon(icon, color: const Color(GarraColors.gold)),
                ),
                const SizedBox(width: GarraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(GarraColors.gold),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedTabChips extends StatelessWidget {
  const _FeedTabChips({required this.tab, required this.onChanged});

  final _HomeFeedTab tab;
  final ValueChanged<_HomeFeedTab> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (_HomeFeedTab.forYou, 'Para ti'),
      (_HomeFeedTab.following, 'Siguiendo'),
      (_HomeFeedTab.match, 'Partido'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items
            .map(
              (m) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(m.$2),
                  selected: tab == m.$1,
                  onSelected: (_) => onChanged(m.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CompactMatchInsert extends StatelessWidget {
  const _CompactMatchInsert({required this.home, required this.onOpenMatch});

  final HomeModel home;
  final VoidCallback onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final match = home.match!;
    final label = home.isLive
        ? 'EN VIVO'
        : home.isMatchday
        ? 'Hoy juega la U'
        : 'Próximo partido';
    final score = home.isLive || home.isFinished
        ? '${match.homeScore ?? '-'} : ${match.awayScore ?? '-'}'
        : 'VS';

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      button: true,
      label: '$label, ${match.homeTeam} $score ${match.awayTeam}',
      child: InkWell(
        onTap: onOpenMatch,
        borderRadius: BorderRadius.circular(GarraRadius.lg),
        child: GarraAtmosphericHero(
          height: 124 + ((textScale - 1).clamp(0, 1) * 34),
          padding: const EdgeInsets.all(GarraSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const GarraCrest(size: 42, showGlow: true),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MatchStatusLabel(
                      label: label,
                      icon: home.isLive ? Icons.sensors : Icons.sports_soccer,
                    ),
                    const SizedBox(height: GarraSpacing.sm),
                    Text(
                      '${match.homeTeam}  $score  ${match.awayTeam}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(GarraColors.cream),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GarraSpacing.xs),
              const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchStatusLabel extends StatelessWidget {
  const _MatchStatusLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(GarraColors.burgundy).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(GarraRadius.pill),
        border: Border.all(
          color: const Color(GarraColors.gold).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(GarraColors.cream)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(GarraColors.cream),
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsoCremaCard extends StatelessWidget {
  const _PulsoCremaCard({
    required this.prediction,
    required this.matchId,
    required this.mvpOpen,
  });

  final HomePrediction prediction;
  final String matchId;
  final bool mvpOpen;

  @override
  Widget build(BuildContext context) {
    final (subtitle, predictionCta) = switch (prediction.state) {
      'PREDICTED' => (
        prediction.predictedHomeScore != null
            ? 'Ya jugaste · ${prediction.predictedHomeScore}-${prediction.predictedAwayScore}'
            : 'Ya jugaste',
        'Ver mi predicción',
      ),
      'LOCKED' => (
        prediction.predictedHomeScore != null
            ? 'Marcador cerrado · ${prediction.predictedHomeScore}-${prediction.predictedAwayScore}'
            : 'Predicción cerrada',
        'Ver mi predicción',
      ),
      'SCORED' => (
        prediction.pointsEarned != null
            ? (prediction.pointsEarned! > 0
                  ? 'Ganaste ${prediction.pointsEarned} pts'
                  : 'Resultado disponible')
            : 'Resultado disponible',
        'Ver resultado',
      ),
      _ => ('Haz tu predicción', 'Hacer predicción'),
    };

    final pollaRoute = '/polla/$matchId';
    final mvpRoute = '/matchday/$matchId/polls';

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pulso Crema',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(GarraColors.cream),
            ),
          ),
          const SizedBox(height: GarraSpacing.xs),
          Text(
            'Opinión del partido, MVP y predicción opcional.',
            style: Theme.of(context).textTheme.bodySmall,
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
          if (mvpOpen) ...[
            GarraPrimaryButton(
              label: 'Vota por el MVP',
              onPressed: () => context.push(mvpRoute),
            ),
            const SizedBox(height: GarraSpacing.sm),
            GarraSecondaryButton(
              label: predictionCta,
              onPressed: () => context.push(pollaRoute),
            ),
          ] else
            GarraPrimaryButton(
              label: predictionCta,
              onPressed: () => context.push(pollaRoute),
            ),
        ],
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
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _computeRemaining();
      final crossed = _remaining.inSeconds > 0 && next.inSeconds <= 0;
      setState(() => _remaining = next);
      if (crossed) {
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
    final dateLabel = DateFormat(
      'EEE d MMM · HH:mm',
    ).format(match.matchDateTime.toLocal());

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

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return GarraAtmosphericHero(
      height: 370 + ((textScale - 1).clamp(0, 1.5) * 180),
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _MatchStatusLabel(
                  label: headline,
                  icon: home.isLive ? Icons.sensors : Icons.stadium_outlined,
                ),
              ),
              if (liveBadge != null)
                Text(
                  liveBadge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(GarraColors.gold),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(
            match.competition.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(GarraColors.gold),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$dateLabel · ${match.stadium}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(GarraColors.creamMuted),
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TeamBlock(
                  name: match.homeTeam,
                  isUniversitario: _isUniversitario(match.homeTeam),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GarraSpacing.xs,
                  GarraSpacing.sm,
                  GarraSpacing.xs,
                  0,
                ),
                child: home.isLive || home.isFinished
                    ? Text(
                        '${match.homeScore ?? '-'} : ${match.awayScore ?? '-'}',
                        style: GarraTypography.numeric(size: 30),
                      )
                    : Text(
                        'VS',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(GarraColors.gold),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              Expanded(
                child: _TeamBlock(
                  name: match.awayTeam,
                  alignEnd: true,
                  isUniversitario: _isUniversitario(match.awayTeam),
                ),
              ),
            ],
          ),
          if (home.isUpcoming || home.isMatchday) ...[
            const SizedBox(height: GarraSpacing.md),
            _MatchCountdown(remaining: _remaining),
          ],
          if (home.isLive || home.isMatchday) ...[
            const SizedBox(height: GarraSpacing.md),
            GarraPrimaryButton(
              label: home.isLive ? 'Entrar al partido' : 'Entrar al Matchday',
              onPressed: () => context.push('/matchday/${match.id}/polls'),
            ),
          ],
          if (home.isFinished) ...[
            const SizedBox(height: GarraSpacing.md),
            GarraSecondaryButton(
              label: 'Ver encuestas',
              onPressed: () => context.push('/matchday/${match.id}/polls'),
            ),
          ],
        ],
      ),
    );
  }

  bool _isUniversitario(String name) {
    final normalized = name.toLowerCase();
    return normalized.contains('universitario') ||
        normalized == 'la u' ||
        normalized == 'u';
  }
}

class _MatchCountdown extends StatelessWidget {
  const _MatchCountdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    if (remaining.inSeconds <= 0) {
      return const Center(child: Text('Kickoff'));
    }
    final values = [
      remaining.inDays,
      remaining.inHours.remainder(24),
      remaining.inMinutes.remainder(60),
      remaining.inSeconds.remainder(60),
    ];
    const labels = ['DD', 'HH', 'MM', 'SS'];

    return Semantics(
      label: 'Cuenta regresiva DD HH MM SS',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < values.length; index++) ...[
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.xs,
                  vertical: GarraSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    GarraColors.surfaceRaised,
                  ).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(GarraRadius.sm),
                  border: Border.all(
                    color: const Color(GarraColors.borderSubtle),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      values[index].toString().padLeft(2, '0'),
                      key: ValueKey('countdown-${labels[index]}'),
                      style: GarraTypography.numeric(
                        size: 18,
                      ).copyWith(color: const Color(GarraColors.cream)),
                    ),
                    Text(
                      labels[index],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(GarraColors.creamMuted),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index < values.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Color(GarraColors.gold),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.name,
    this.alignEnd = false,
    this.isUniversitario = false,
  });

  final String name;
  final bool alignEnd;
  final bool isUniversitario;

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
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (isUniversitario)
          const GarraCrest(size: 52, showGlow: true)
        else
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(
                GarraColors.surfaceRaised,
              ).withValues(alpha: 0.88),
              shape: BoxShape.circle,
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

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.checkIn, this.matchId});

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
  const _MissionStreakSection({this.mission, this.streak, this.matchId});

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
            streak: StreakSummary(current: streak!.current, best: streak!.best),
            compact: true,
          ),
      ],
    );
  }
}
