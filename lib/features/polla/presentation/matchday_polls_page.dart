import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/matchday_poll_models.dart';
import 'providers/polla_provider.dart';
import 'widgets/garra_mvp_poll.dart';
import 'widgets/garra_poll_card.dart';

class MatchdayPollsPage extends ConsumerStatefulWidget {
  const MatchdayPollsPage({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchdayPollsPage> createState() => _MatchdayPollsPageState();
}

class _MatchdayPollsPageState extends ConsumerState<MatchdayPollsPage> {
  final Set<String> _submitting = {};
  final Map<String, MatchPollResults> _resultsCache = {};
  final Set<String> _loadingResults = {};

  Future<void> _ensureResults(List<MatchPoll> polls) async {
    for (final poll in polls) {
      if (_resultsCache.containsKey(poll.id) ||
          _loadingResults.contains(poll.id)) {
        continue;
      }
      _loadingResults.add(poll.id);
      try {
        final results =
            await ref.read(pollaServiceProvider).getPollResults(poll.id);
        if (!mounted) return;
        setState(() => _resultsCache[poll.id] = results);
      } catch (_) {
        // Keep options visible without percentages until vote.
      } finally {
        _loadingResults.remove(poll.id);
      }
    }
  }

  Future<void> _vote(MatchPoll poll, String optionId) async {
    if (_submitting.contains(poll.id)) return;
    setState(() => _submitting.add(poll.id));
    try {
      final results = await ref.read(pollaServiceProvider).vote(
            pollId: poll.id,
            optionId: optionId,
          );
      if (!mounted) return;
      setState(() {
        _resultsCache[poll.id] = results;
      });
      ref.invalidate(matchdayPollsProvider(widget.matchId));
      ref.invalidate(matchdayProvider(widget.matchId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo registrar tu voto. IntÃ©ntalo de nuevo.'),
          backgroundColor: Color(GarraColors.danger),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting.remove(poll.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pollsAsync = ref.watch(matchdayPollsProvider(widget.matchId));
    final matchdayAsync = ref.watch(matchdayProvider(widget.matchId));

    ref.listen(matchdayPollsProvider(widget.matchId), (previous, next) {
      next.whenData(_ensureResults);
    });

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Encuestas Matchday'),
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
      body: pollsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (e, st) => GarraErrorState(
          title: 'No pudimos cargar las encuestas',
          onRetry: () {
            ref.invalidate(matchdayPollsProvider(widget.matchId));
            ref.invalidate(matchdayProvider(widget.matchId));
          },
        ),
        data: (polls) {
          if (polls.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(GarraSpacing.lg),
              child: GarraPollEmptyState(),
            );
          }

          final matchTitle = matchdayAsync.maybeWhen(
            data: (m) => '${m.match.homeTeam} vs ${m.match.awayTeam}',
            orElse: () => null,
          );

          final general = polls.where((p) => !p.isMvp).toList();
          final mvp = polls.where((p) => p.isMvp).toList();

          return RefreshIndicator(
            color: const Color(GarraColors.gold),
            onRefresh: () async {
              _resultsCache.clear();
              ref.invalidate(matchdayPollsProvider(widget.matchId));
              ref.invalidate(matchdayProvider(widget.matchId));
              await ref.read(matchdayPollsProvider(widget.matchId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              children: [
                if (matchTitle != null) ...[
                  GarraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          matchTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: GarraSpacing.sm),
                        GarraSecondaryButton(
                          label: 'Ir a La Polla',
                          onPressed: () =>
                              context.push('/polla/${widget.matchId}'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.lg),
                ],
                if (mvp.isNotEmpty) ...[
                  const GarraSectionHeader(
                    title: 'MVP del partido',
                    subtitle: 'Vota por el mejor jugador',
                  ),
                  const SizedBox(height: GarraSpacing.md),
                  ...mvp.map((poll) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: GarraSpacing.lg),
                      child: GarraMvpPoll(
                        poll: poll,
                        results: _resultsCache[poll.id],
                        submitting: _submitting.contains(poll.id),
                        onVote: poll.isOpen
                            ? (optionId) => _vote(poll, optionId)
                            : null,
                      ),
                    );
                  }),
                ],
                if (general.isNotEmpty) ...[
                  const GarraSectionHeader(
                    title: 'Encuestas',
                    subtitle: 'Opina con la hinchada',
                  ),
                  const SizedBox(height: GarraSpacing.md),
                  ...general.map((poll) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: GarraSpacing.lg),
                      child: GarraPollCard.fromPoll(
                        poll: poll,
                        results: _resultsCache[poll.id],
                        submitting: _submitting.contains(poll.id),
                        onVote: poll.isOpen
                            ? (optionId) => _vote(poll, optionId)
                            : null,
                      ),
                    );
                  }),
                ],
                if (mvp.isEmpty && general.isEmpty)
                  const GarraPollEmptyState(),
              ],
            ),
          );
        },
      ),
    );
  }
}
