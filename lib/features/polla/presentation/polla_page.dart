import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../../matches/presentation/providers/matches_provider.dart';
import '../../predictions/data/create_prediction_request.dart';
import '../../ranking/presentation/providers/ranking_provider.dart';
import '../data/polla_models.dart';
import 'providers/polla_provider.dart';

/// FIRST_SCORER_UI_SOURCE = FREE_TEXT
class PollaPage extends ConsumerWidget {
  const PollaPage({super.key, this.matchId});

  final String? matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedId = matchId;
    if (resolvedId != null && resolvedId.isNotEmpty) {
      return _PollaMatchScreen(matchId: resolvedId);
    }

    final homeAsync = ref.watch(homeProvider);
    final matchesAsync = ref.watch(upcomingMatchesProvider);

    return homeAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(GarraColors.charcoal),
        body: Center(child: CircularProgressIndicator(color: Color(GarraColors.gold))),
      ),
      error: (error, stackTrace) => matchesAsync.when(
        loading: () => const Scaffold(
          backgroundColor: Color(GarraColors.charcoal),
          body: Center(child: CircularProgressIndicator(color: Color(GarraColors.gold))),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: Color(GarraColors.charcoal),
          appBar: AppBar(title: const Text('La Polla')),
          body: GarraErrorState(onRetry: () {
            ref.invalidate(homeProvider);
            ref.invalidate(upcomingMatchesProvider);
          }),
        ),
        data: (matches) {
          if (matches.isEmpty) {
            return Scaffold(
              backgroundColor: const Color(GarraColors.charcoal),
              appBar: AppBar(title: const Text('La Polla')),
              body: const GarraEmptyState(
                title: 'No hay partidos disponibles',
                message:
                    'Cuando existan partidos abiertos para predicción, aparecerán aquí.',
              ),
            );
          }
          if (matches.length == 1) {
            return _PollaMatchScreen(matchId: matches.first.id);
          }
          return _PollaMatchPicker(matchIds: matches.map((m) => (
                id: m.id,
                home: m.homeTeam,
                away: m.awayTeam,
              )).toList());
        },
      ),
      data: (home) {
        final fromHome = home.prediction.matchId ?? home.match?.id;
        if (fromHome != null && fromHome.isNotEmpty) {
          return _PollaMatchScreen(matchId: fromHome);
        }
        return matchesAsync.when(
          loading: () => const Scaffold(
            backgroundColor: Color(GarraColors.charcoal),
            body: Center(child: CircularProgressIndicator(color: Color(GarraColors.gold))),
          ),
          error: (e, st) => Scaffold(
            backgroundColor: const Color(GarraColors.charcoal),
            appBar: AppBar(title: const Text('La Polla')),
            body: GarraErrorState(onRetry: () {
              ref.invalidate(homeProvider);
              ref.invalidate(upcomingMatchesProvider);
            }),
          ),
          data: (matches) {
            if (matches.isEmpty) {
              return Scaffold(
                backgroundColor: const Color(GarraColors.charcoal),
                appBar: AppBar(title: const Text('La Polla')),
                body: const GarraEmptyState(
                  title: 'No hay partidos disponibles',
                  message:
                      'Cuando existan partidos abiertos para predicción, aparecerán aquí.',
                ),
              );
            }
            return _PollaMatchScreen(matchId: matches.first.id);
          },
        );
      },
    );
  }
}

class _PollaMatchPicker extends StatelessWidget {
  const _PollaMatchPicker({required this.matchIds});

  final List<({String id, String home, String away})> matchIds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('La Polla')),
      body: ListView.separated(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        itemCount: matchIds.length,
        separatorBuilder: (context, index) => const SizedBox(height: GarraSpacing.md),
        itemBuilder: (context, index) {
          final m = matchIds[index];
          return GarraCard(
            onTap: () => context.push('/polla/${m.id}'),
            child: Text(
              '${m.home} vs ${m.away}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        },
      ),
    );
  }
}

class _PollaMatchScreen extends ConsumerWidget {
  const _PollaMatchScreen({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollaAsync = ref.watch(pollaProvider(matchId));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('La Polla'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: pollaAsync.when(
        loading: () => const _PollaLoading(),
        error: (error, _) => GarraErrorState(
          title: 'No pudimos cargar La Polla',
          message: 'Revisa tu conexión e inténtalo de nuevo.',
          onRetry: () => ref.invalidate(pollaProvider(matchId)),
        ),
        data: (polla) => RefreshIndicator(
          color: const Color(GarraColors.gold),
          onRefresh: () async => ref.invalidate(pollaProvider(matchId)),
          child: _PollaBody(polla: polla),
        ),
      ),
    );
  }
}

class _PollaLoading extends StatelessWidget {
  const _PollaLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: const [
        GarraSkeleton(height: 140),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 48),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 180),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 120),
      ],
    );
  }
}

class _PollaBody extends ConsumerWidget {
  const _PollaBody({required this.polla});

  final PollaResponse polla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        GarraSpacing.section,
      ),
      children: [
        _MatchHero(polla: polla),
        const SizedBox(height: GarraSpacing.lg),
        _StateBadge(state: polla.state),
        const SizedBox(height: GarraSpacing.lg),
        if (polla.isNotOpen)
          const GarraEmptyState(
            title: 'La Polla aún no abre',
            message: 'Vuelve más cerca del partido para registrar tu predicción.',
          )
        else if (polla.isLocked && !(polla.myPrediction?.hasScores ?? false))
          const _ClosedBanner()
        else ...[
          if (polla.canEdit)
            _PredictionEditor(polla: polla)
          else if (polla.myPrediction?.hasScores ?? false)
            _SubmittedSummary(polla: polla),
          if (polla.isLocked && (polla.myPrediction?.hasScores ?? false)) ...[
            const SizedBox(height: GarraSpacing.md),
            const _ClosedBanner(),
          ],
        ],
        if (polla.isScored && polla.myPrediction?.breakdown != null) ...[
          const SizedBox(height: GarraSpacing.lg),
          _ResultBreakdown(polla: polla),
        ],
        const SizedBox(height: GarraSpacing.lg),
        _Participation(count: polla.participants),
        const SizedBox(height: GarraSpacing.lg),
        _SentimentCard(
          sentiment: polla.sentiment,
          homeTeam: polla.match.homeTeam,
          awayTeam: polla.match.awayTeam,
        ),
        const SizedBox(height: GarraSpacing.lg),
        _RulesCard(rules: polla.rules),
        const SizedBox(height: GarraSpacing.lg),
        GarraSecondaryButton(
          label: 'Ver encuestas del partido',
          onPressed: () => context.push('/matchday/${polla.match.id}/polls'),
        ),
      ],
    );
  }
}

class _MatchHero extends StatelessWidget {
  const _MatchHero({required this.polla});

  final PollaResponse polla;

  @override
  Widget build(BuildContext context) {
    final match = polla.match;
    final dateLabel = DateFormat('EEE d MMM Â· HH:mm').format(
      match.matchDateTime.toLocal(),
    );
    final closes = polla.closesAt ?? match.predictionClosesAt;

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match.competition,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(GarraColors.gold),
                ),
          ),
          const SizedBox(height: GarraSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  match.homeTeam,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.sm),
                child: match.homeScore != null && match.awayScore != null
                    ? Text(
                        '${match.homeScore} : ${match.awayScore}',
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
              Expanded(
                child: Text(
                  match.awayTeam,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: GarraSpacing.md),
          Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: GarraSpacing.xs),
          Text(match.stadium, style: Theme.of(context).textTheme.bodySmall),
          if (closes != null) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              'Cierra: ${DateFormat('d MMM Â· HH:mm').format(closes.toLocal())}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      'OPEN' => ('Abierta', const Color(GarraColors.success)),
      'SUBMITTED' => ('Ya jugaste', const Color(GarraColors.gold)),
      'LOCKED' => ('Cerrada', const Color(GarraColors.warning)),
      'SCORED' => ('Puntuada', const Color(GarraColors.success)),
      _ => ('Próximamente', const Color(GarraColors.textSecondary)),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: GarraSpacing.md,
          vertical: GarraSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(GarraRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: Color(GarraColors.warning)),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Text(
              'La Polla cerró. Ya no se pueden cambiar predicciones.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedSummary extends StatelessWidget {
  const _SubmittedSummary({required this.polla});

  final PollaResponse polla;

  @override
  Widget build(BuildContext context) {
    final pred = polla.myPrediction!;
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu predicción', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: GarraSpacing.sm),
          Text(
            '${pred.homeScore} - ${pred.awayScore}',
            style: GarraTypography.numeric(size: 32),
          ),
          if (pred.firstScorer != null && pred.firstScorer!.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              'Primer goleador: ${pred.firstScorer}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionEditor extends ConsumerStatefulWidget {
  const _PredictionEditor({required this.polla});

  final PollaResponse polla;

  @override
  ConsumerState<_PredictionEditor> createState() => _PredictionEditorState();
}

class _PredictionEditorState extends ConsumerState<_PredictionEditor> {
  static const int maxScore = 20;

  late int _home;
  late int _away;
  late final TextEditingController _firstScorer;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final pred = widget.polla.myPrediction;
    _home = pred?.homeScore ?? 0;
    _away = pred?.awayScore ?? 0;
    _firstScorer = TextEditingController(text: pred?.firstScorer ?? '');
  }

  @override
  void dispose() {
    _firstScorer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final service = ref.read(pollaServiceProvider);
      final result = await service.upsertPrediction(
        CreatePredictionRequest(
          matchId: widget.polla.match.id,
          predictedHomeScore: _home,
          predictedAwayScore: _away,
          predictedFirstScorer: _firstScorer.text.trim().isEmpty
              ? null
              : _firstScorer.text.trim(),
        ),
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(GarraColors.success),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(pollaProvider(widget.polla.match.id));
        ref.invalidate(homeProvider);
        ref.invalidate(rankingProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(GarraColors.warning),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final backendMessage = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(backendMessage ?? 'No se pudo registrar la predicción.'),
          backgroundColor: const Color(GarraColors.danger),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.polla.match;
    final hasExisting = widget.polla.myPrediction?.hasScores ?? false;

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasExisting ? 'Actualiza tu predicciónón' : 'Haz tu predicciónón',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.lg),
          _ScoreStepper(
            label: match.homeTeam,
            value: _home,
            onChanged: (v) => setState(() => _home = v),
          ),
          const SizedBox(height: GarraSpacing.md),
          _ScoreStepper(
            label: match.awayTeam,
            value: _away,
            onChanged: (v) => setState(() => _away = v),
          ),
          const SizedBox(height: GarraSpacing.lg),
          TextField(
            controller: _firstScorer,
            textInputAction: TextInputAction.done,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Primer goleador (opcional)',
              hintText: 'Nombre del jugador',
              counterText: '',
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          GarraPrimaryButton(
            label: hasExisting ? 'Actualizar predicción' : 'Registrar predicción',
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Bajar',
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: const Color(GarraColors.gold),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: GarraTypography.numeric(size: 28),
          ),
        ),
        IconButton(
          tooltip: 'Subir',
          onPressed: value < _PredictionEditorState.maxScore
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline),
          color: const Color(GarraColors.gold),
        ),
      ],
    );
  }
}

class _Participation extends StatelessWidget {
  const _Participation({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final formatted = count.toString();
    return GarraCard(
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: Color(GarraColors.gold)),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Text(
              count == 0
                  ? 'Sé el primero en jugar La Polla'
                  : '$formatted cremas ya jugaron',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SentimentCard extends StatelessWidget {
  const _SentimentCard({
    required this.sentiment,
    required this.homeTeam,
    required this.awayTeam,
  });

  final PollaSentiment sentiment;
  final String homeTeam;
  final String awayTeam;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Así vota la hinchada',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.xs),
          Text(
            'Sentimiento de la comunidad Â· no es probabilidad',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: GarraSpacing.lg),
          _SentimentBar(
            label: homeTeam,
            percent: sentiment.homeWinPercent,
          ),
          const SizedBox(height: GarraSpacing.sm),
          _SentimentBar(
            label: 'Empate',
            percent: sentiment.drawPercent,
          ),
          const SizedBox(height: GarraSpacing.sm),
          _SentimentBar(
            label: awayTeam,
            percent: sentiment.awayWinPercent,
          ),
        ],
      ),
    );
  }
}

class _SentimentBar extends StatelessWidget {
  const _SentimentBar({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text('$percent%', style: GarraTypography.numeric(size: 16)),
          ],
        ),
        const SizedBox(height: GarraSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(GarraRadius.pill),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(GarraColors.surfaceRaised),
            color: const Color(GarraColors.gold),
          ),
        ),
      ],
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.rules});

  final PollaRulesInfo rules;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reglas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: GarraSpacing.md),
          _RuleRow(label: 'Marcador exacto', points: rules.exactScorePoints),
          _RuleRow(label: 'Resultado correcto', points: rules.outcomePoints),
          _RuleRow(label: 'Primer goleador', points: rules.firstScorerPoints),
          if (rules.note != null && rules.note!.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(rules.note!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.points});

  final String label;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text('+$points', style: GarraTypography.numeric(size: 16)),
        ],
      ),
    );
  }
}

class _ResultBreakdown extends StatelessWidget {
  const _ResultBreakdown({required this.polla});

  final PollaResponse polla;

  @override
  Widget build(BuildContext context) {
    final pred = polla.myPrediction!;
    final b = pred.breakdown!;
    final match = polla.match;

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resultado', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: GarraSpacing.sm),
          Text(
            'Oficial: ${match.homeScore ?? '-'} - ${match.awayScore ?? '-'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Tu predicción: ${pred.homeScore} - ${pred.awayScore}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: GarraSpacing.lg),
          _RuleRow(
            label: 'Marcador exacto',
            points: b.exactScorePoints,
          ),
          _RuleRow(
            label: 'Resultado correcto',
            points: b.outcomePoints,
          ),
          _RuleRow(
            label: 'Primer goleador',
            points: b.firstScorerPoints,
          ),
          const Divider(height: GarraSpacing.xxl),
          Text(
            b.totalPoints > 0
                ? 'Sumaste ${b.totalPoints} Puntos Garra'
                : 'Esta vez no sumaste puntos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(GarraColors.gold),
                ),
          ),
        ],
      ),
    );
  }
}
