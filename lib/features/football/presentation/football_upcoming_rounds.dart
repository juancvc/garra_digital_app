import 'package:flutter/material.dart';

import '../data/garra_football_models.dart';
import 'football_match_card.dart';

/// SONIC_05 PRÓXIMOS for one competition: competition name + compact round selector. The active
/// round is the next relevant one (see [footballActiveRound]); the selected round shows ALL its
/// fixtures, featured team first (presentation order only), and rounds change in place.
class FootballUpcomingRounds extends StatelessWidget {
  const FootballUpcomingRounds({super.key, required this.competitionName, required this.matches,
    required this.selectedRound, required this.onRoundChanged, required this.onOpen, this.onTeamTap,
    this.featuredNextId, this.header = const []});
  final String competitionName;
  final List<FootballMatch> matches;
  final String? selectedRound;
  final ValueChanged<String> onRoundChanged;
  final ValueChanged<FootballMatch> onOpen;
  final FootballTeamTap? onTeamTap;
  final int? featuredNextId;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rounds = footballRounds(matches);
    final active = rounds.any((r) => r.key == selectedRound) ? selectedRound
        : footballActiveRound(rounds, limaNow: limaWallClock(DateTime.now()), featuredNextId: featuredNextId);
    final round = rounds.where((r) => r.key == active).firstOrNull;
    final ordered = [...?round?.matches]..sort((a, b) {
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      return (a.kickoff ?? DateTime(9999)).compareTo(b.kickoff ?? DateTime(9999));
    });
    return ListView(
      key: const ValueKey('upcoming_rounds'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ...header,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(competitionName, key: const ValueKey('rounds_competition'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ),
        if (rounds.length > 1) _RoundSelector(rounds: rounds, selected: active, onSelected: onRoundChanged),
        if (round != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Text('${round.label} · ${round.matches.length} partidos',
                key: const ValueKey('round_summary'), style: text.labelMedium),
          ),
        for (final m in ordered)
          FootballMatchCard(key: ValueKey('match_${m.id}'), match: m, showCompetitionHeader: false,
              onTap: () => onOpen(m), onTeamTap: onTeamTap),
      ],
    );
  }
}

class _RoundSelector extends StatefulWidget {
  const _RoundSelector({required this.rounds, required this.selected, required this.onSelected});
  final List<FootballRound> rounds;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  State<_RoundSelector> createState() => _RoundSelectorState();
}

class _RoundSelectorState extends State<_RoundSelector> {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyFor(String round) => _keys.putIfAbsent(round, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(covariant _RoundSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal(animate: true);
  }

  /// The active round is always visible on entry (never hidden past the edge).
  void _reveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = widget.selected == null ? null : _keys[widget.selected!]?.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(ctx, alignment: 0.5,
          duration: animate ? const Duration(milliseconds: 200) : Duration.zero);
    });
  }

  @override
  Widget build(BuildContext context) {
    final garra = garraColors(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          for (final r in widget.rounds)
            Padding(
              key: _keyFor(r.key),
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                key: ValueKey('round_${r.key}'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => widget.onSelected(r.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: r.key == widget.selected ? garra.brandPrimary : Colors.transparent,
                    border: Border.all(color: r.key == widget.selected ? garra.brandPrimary : scheme.outlineVariant),
                  ),
                  child: Text(r.label, style: text.labelMedium?.copyWith(
                      fontWeight: r.key == widget.selected ? FontWeight.w900 : FontWeight.w600,
                      color: r.key == widget.selected ? garra.onBrand : null)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
