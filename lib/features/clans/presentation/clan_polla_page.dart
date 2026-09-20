import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/clan_models.dart';
import '../data/clan_service.dart';
import 'providers/clans_provider.dart';

class ClanPollaPage extends ConsumerWidget {
  const ClanPollaPage({
    super.key,
    required this.slug,
    this.matchId,
  });

  final String slug;
  final String? matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeProvider);
    final resolvedMatchId = matchId?.isNotEmpty == true
        ? matchId
        : homeAsync.asData?.value.match?.id;

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Polla del Clan')),
      body: resolvedMatchId == null || resolvedMatchId.isEmpty
          ? const _NoMatchBody()
          : _ClanPollaBody(slug: slug, matchId: resolvedMatchId),
    );
  }
}

class _NoMatchBody extends StatelessWidget {
  const _NoMatchBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(GarraSpacing.xl),
        child: GarraEmptyState(
          title: 'Sin partido activo',
          message:
              'Cuando haya un partido con La Polla abierta, aquí verás la participación de tu clan.',
        ),
      ),
    );
  }
}

class _ClanPollaBody extends ConsumerWidget {
  const _ClanPollaBody({required this.slug, required this.matchId});

  final String slug;
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ClanPollaParams(slug: slug, matchId: matchId);
    final pollaAsync = ref.watch(clanPollaProvider(params));
    final year = DateTime.now().year;
    final rankingAsync = ref.watch(
      clanMemberRankingProvider(
        ClanMemberRankingParams(slug: slug, year: year),
      ),
    );

    return pollaAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(GarraColors.gold)),
      ),
      error: (error, _) {
        if (error is ClanMembershipLostException) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(GarraSpacing.xl),
              child: GarraEmptyState(
                title: 'Acceso restringido',
                message: error.message,
              ),
            ),
          );
        }
        return GarraErrorState(
          onRetry: () => ref.invalidate(clanPollaProvider(params)),
        );
      },
      data: (polla) {
        if (polla.isNoMatch) {
          return const _NoMatchBody();
        }

        return RefreshIndicator(
          color: const Color(GarraColors.gold),
          onRefresh: () async {
            ref.invalidate(clanPollaProvider(params));
            ref.invalidate(
              clanMemberRankingProvider(
                ClanMemberRankingParams(slug: slug, year: year),
              ),
            );
            await ref.read(clanPollaProvider(params).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.md,
              GarraSpacing.lg,
              GarraSpacing.section,
            ),
            children: [
              _MatchHeader(polla: polla),
              const SizedBox(height: GarraSpacing.lg),
              _ParticipationCard(polla: polla),
              const SizedBox(height: GarraSpacing.lg),
              _MyPredictionCard(polla: polla),
              const SizedBox(height: GarraSpacing.lg),
              if (polla.isPrelock) ...[
                const GarraCard(
                  child: Text(
                    'Las predicciones del clan se revelan cuando cierre La Polla.',
                    style: TextStyle(color: Color(GarraColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: GarraSpacing.lg),
                GarraPrimaryButton(
                  label: 'Hacer mi Polla',
                  onPressed: () => context.push('/polla/$matchId'),
                ),
              ],
              if (polla.isLocked || polla.isScored) ...[
                const GarraSectionHeader(
                  title: 'Predicciones del clan',
                  subtitle: 'Miembros que ya jugaron',
                ),
                const SizedBox(height: GarraSpacing.md),
                if (polla.memberPredictions.isEmpty)
                  const GarraCard(
                    child: Text(
                      'Aún no hay predicciones reveladas.',
                      style:
                          TextStyle(color: Color(GarraColors.textSecondary)),
                    ),
                  )
                else
                  ...polla.memberPredictions.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                      child: _MemberPredictionTile(
                        member: m,
                        showPoints: polla.isScored,
                      ),
                    ),
                  ),
              ],
              if (polla.isScored && polla.scoredSummary != null) ...[
                const SizedBox(height: GarraSpacing.lg),
                GarraCard(
                  child: Text(
                    'Puntos del clan en este partido: '
                    '${polla.scoredSummary!.totalClanPoints}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
              const SizedBox(height: GarraSpacing.xxl),
              GarraSectionHeader(
                title: 'Ranking Polla · $year',
                subtitle: 'Puntos del año en el clan',
              ),
              const SizedBox(height: GarraSpacing.md),
              rankingAsync.when(
                loading: () => const GarraSkeleton(height: 80),
                error: (_, __) => const SizedBox.shrink(),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const GarraEmptyState(
                      title: 'Sin ranking aún',
                      message:
                          'Cuando haya predicciones puntuadas, verás el ranking aquí.',
                    );
                  }
                  return Column(
                    children: entries
                        .map(
                          (e) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: GarraSpacing.sm),
                            child: _MemberRankTile(entry: e),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.polla});

  final ClanPollaMatchModel polla;

  @override
  Widget build(BuildContext context) {
    final match = polla.match!;
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${match.homeTeam} vs ${match.awayTeam}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (match.competition != null && match.competition!.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.xs),
            Text(
              match.competition!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: GarraSpacing.sm),
          Text(
            _stateLabel(polla.state),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(GarraColors.gold),
                ),
          ),
        ],
      ),
    );
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'OPEN':
        return 'Polla abierta';
      case 'SUBMITTED':
        return 'Ya jugaste';
      case 'LOCKED':
        return 'Polla cerrada';
      case 'SCORED':
        return 'Puntaje disponible';
      default:
        return state;
    }
  }
}

class _ParticipationCard extends StatelessWidget {
  const _ParticipationCard({required this.polla});

  final ClanPollaMatchModel polla;

  @override
  Widget build(BuildContext context) {
    final x = NumberFormat.decimalPattern('es').format(polla.participantCount);
    final y = NumberFormat.decimalPattern('es').format(polla.memberCount);
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Participación',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(
            '$x de $y miembros ya jugaron',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (polla.participationPercent != null) ...[
            const SizedBox(height: GarraSpacing.xs),
            Text(
              '${polla.participationPercent!.toStringAsFixed(0)}% del clan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MyPredictionCard extends StatelessWidget {
  const _MyPredictionCard({required this.polla});

  final ClanPollaMatchModel polla;

  @override
  Widget build(BuildContext context) {
    final pred = polla.myPrediction;
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mi predicción',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(
            pred?.hasScores == true ? pred!.scoreLabel : 'Aún no jugaste',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (pred?.firstScorer != null && pred!.firstScorer!.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.xs),
            Text(
              'Primer gol: ${pred.firstScorer}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (polla.isScored && pred?.pointsEarned != null) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              '${pred!.pointsEarned} pts',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(GarraColors.gold),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberPredictionTile extends StatelessWidget {
  const _MemberPredictionTile({
    required this.member,
    required this.showPoints,
  });

  final ClanPollaMemberPrediction member;
  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Row(
        children: [
          if (member.rank != null && showPoints)
            SizedBox(
              width: 36,
              child: Text(
                '#${member.rank}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(GarraColors.gold),
                    ),
              ),
            ),
          GarraAvatar(
            displayName: member.displayName,
            avatarUrl: member.avatarUrl,
            size: 40,
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  member.scoreLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (showPoints && member.pointsEarned != null)
            Text(
              '${member.pointsEarned} pts',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(GarraColors.gold),
                  ),
            ),
        ],
      ),
    );
  }
}

class _MemberRankTile extends StatelessWidget {
  const _MemberRankTile({required this.entry});

  final ClanMemberRankingEntry entry;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(GarraColors.gold),
                  ),
            ),
          ),
          GarraAvatar(
            displayName: entry.displayName,
            avatarUrl: entry.avatarUrl,
            size: 40,
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Text(
              entry.displayName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Text(
            '${entry.predictionPoints} pts',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
