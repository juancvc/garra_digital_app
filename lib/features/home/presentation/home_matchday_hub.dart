import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config_service.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../missions/data/mission_models.dart';
import '../../missions/presentation/widgets/garra_streak_card.dart';
import '../data/home_models.dart';
import 'providers/home_provider.dart';

// PRODUCT-10A.2E: Matchday surfaces recovered verbatim from RC2
// (e2d95ac:lib/features/home/presentation/home_page.dart, ex pestaña
// 'Partido' de Home). They now live in Centro Garra (Para ti · Hoy) and the
// countdown in the match detail. Same providers, routes and conditions; no
// new contracts. They are NOT shown in Home.

/// Pulso Crema (Polla + MVP), Check-in and Misiones/Racha from the existing
/// [homeProvider] (same `/home` contract). Renders nothing while loading, on
/// error (e.g. signed out) or when there is nothing to show.
class HomeMatchdayHubSection extends ConsumerWidget {
  const HomeMatchdayHubSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider).asData?.value;
    if (home == null) return const SizedBox.shrink();
    final children = <Widget>[];
    void add(Widget w) {
      if (children.isNotEmpty) children.add(const SizedBox(height: GarraSpacing.md));
      children.add(w);
    }
    // PRODUCT-10A.2F: RC2 hero CTA ('Entrar al partido' / 'Entrar al
    // Matchday') with the same conditions (live or matchday) and route,
    // independent of MVP voting; hidden when the `matchday` flag is off
    // (the route itself is `_featureOrDisabled('matchday')`).
    if (home.hasMatch &&
        (home.isLive || home.isMatchday) &&
        appConfigService.current.feature('matchday')) {
      final matchId = home.match!.id;
      add(GarraPrimaryButton(
        key: const ValueKey('centro_enter_matchday'),
        label: home.isLive ? 'Entrar al partido' : 'Entrar al Matchday',
        onPressed: () => context.push('/matchday/$matchId/polls'),
      ));
    }
    if (home.hasMatch) {
      add(_PulsoCremaCard(
        prediction: home.prediction,
        matchId: home.match!.id,
        mvpOpen: home.mvpOpen,
      ));
    }
    if (home.checkIn.showCheckInCta) {
      add(_CheckInCard(checkIn: home.checkIn, matchId: home.match?.id));
    }
    if (home.mission != null || home.streak != null) {
      add(_MissionStreakSection(
        mission: home.mission,
        streak: home.streak,
        matchId: home.match?.id,
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('centro_matchday_hub'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// RC2 hero countdown (DD HH MM SS) with its 1 s ticker, fed by an absolute
/// kickoff instant. Hidden once the kickoff has passed. No provider work.
class MatchKickoffCountdown extends StatefulWidget {
  const MatchKickoffCountdown({super.key, required this.kickoffUtc});
  final DateTime kickoffUtc;

  @override
  State<MatchKickoffCountdown> createState() => _MatchKickoffCountdownState();
}

class _MatchKickoffCountdownState extends State<MatchKickoffCountdown> {
  Timer? _ticker;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _computeRemaining());
      if (_remaining.inSeconds <= 0) _ticker?.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _computeRemaining() => widget.kickoffUtc.difference(DateTime.now().toUtc());

  @override
  Widget build(BuildContext context) {
    if (_remaining.inSeconds <= 0) return const SizedBox.shrink();
    return MatchCountdownBlocks(remaining: _remaining);
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
              color: context.garraColors.textPrimary,
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

class MatchCountdownBlocks extends StatelessWidget {
  const MatchCountdownBlocks({super.key, required this.remaining});

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
