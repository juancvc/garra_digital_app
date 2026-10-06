import 'package:flutter/material.dart';

import '../data/garra_football_models.dart';
import 'football_match_card.dart';
import 'football_team_crest.dart';

/// SONIC_05 Detail V5 lineups: one card per team — crest, team, formation, DT, numbered starting
/// XI and substitutes. Provider data only; missing numbers stay blank (never invented).
class FootballLineupCard extends StatelessWidget {
  const FootballLineupCard({super.key, required this.lineup, this.fallbackCrest});
  final FootballLineup lineup;
  final String? fallbackCrest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final garra = garraColors(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            FootballTeamCrest(name: lineup.team, url: lineup.crestUrl ?? fallbackCrest, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Text(lineup.team, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            if (lineup.formation != null)
              Container(
                key: const ValueKey('lineup_formation'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: garra.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(lineup.formation!, style: text.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
              ),
          ]),
          if (lineup.coach != null) ...[
            const SizedBox(height: 6),
            Text('DT · ${lineup.coach}', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          _title(context, 'Titulares'),
          for (final p in lineup.starting) _PlayerRow(player: p),
          if (lineup.bench.isNotEmpty) ...[
            const SizedBox(height: 10),
            _title(context, 'Suplentes'),
            for (final p in lineup.bench) _PlayerRow(player: p, bench: true),
          ],
        ]),
      ),
    );
  }

  Widget _title(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w900, letterSpacing: 0.8, color: garraColors(context).brandPrestige)),
  );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, this.bench = false});
  final FootballLineupPlayer player;
  final bool bench;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final garra = garraColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bench ? scheme.surfaceContainerHighest : garra.brandPrimary.withValues(alpha: 0.14),
          ),
          child: Text(player.number?.toString() ?? '', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(player.name, style: text.bodyMedium?.copyWith(
            fontWeight: bench ? FontWeight.w500 : FontWeight.w700))),
        if (player.positionLabel != null)
          Text(player.positionLabel!, style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
