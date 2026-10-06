import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/garra_football_models.dart';
import 'football_team_crest.dart';

DateFormat _fmt(String pattern) {
  try {
    return DateFormat(pattern, 'es_PE');
  } on Exception {
    return DateFormat(pattern);
  }
}

/// SONIC_02 premium match row: competition · round, crests, score/time hero, truncated names.
class FootballMatchCard extends StatelessWidget {
  const FootballMatchCard({super.key, required this.match, required this.onTap});
  final FootballMatch match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final live = match.isLive;
    final featured = match.featured;
    final competitionLine = [
      if (match.competition.isNotEmpty) match.competition,
      ?match.roundLabel,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(competitionLine.isEmpty ? 'Competición' : competitionLine,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                        color: featured ? Theme.of(context).colorScheme.primary : null,
                        fontWeight: featured ? FontWeight.w800 : null)),
              ),
              if (featured)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.star_rounded, size: 16,
                      color: Theme.of(context).colorScheme.primary),
                ),
              _StatusPill(match: match),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              FootballTeamCrest(name: match.home, url: match.homeCrestUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(match.home, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              _ScoreOrTime(match: match, live: live),
              Expanded(
                child: Text(match.away, maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              FootballTeamCrest(name: match.away, url: match.awayCrestUrl),
            ]),
            if (match.kickoff != null && match.isScheduled) ...[
              const SizedBox(height: 8),
              Text('${_fmt("EEE d MMM · HH:mm").format(match.kickoff!)} (Lima)',
                  style: text.bodySmall),
            ],
          ]),
        ),
      ),
    );
  }
}

class _ScoreOrTime extends StatelessWidget {
  const _ScoreOrTime({required this.match, required this.live});
  final FootballMatch match;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: live ? Colors.red.shade700 : null,
        );
    if (match.isFinished || match.isLive || match.homeScore != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('${match.homeScore ?? '–'} : ${match.awayScore ?? '–'}', style: style),
      );
    }
    final kickoff = match.kickoff;
    final label = kickoff == null ? '–' : _fmt('HH:mm').format(kickoff);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(label, style: style),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.match});
  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    final live = match.isLive;
    final color = live
        ? Colors.red
        : match.isFinished
            ? Theme.of(context).colorScheme.outline
            : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(match.statusLabel,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}
