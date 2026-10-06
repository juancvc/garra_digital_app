import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../data/garra_football_models.dart';
import 'football_team_crest.dart';

DateFormat _fmt(String pattern) {
  try {
    return DateFormat(pattern, 'es_PE');
  } on Exception {
    return DateFormat(pattern);
  }
}

/// Garra colors with a safe fallback when a screen runs without the Garra theme.
GarraSemanticColors garraColors(BuildContext context) =>
    Theme.of(context).extension<GarraSemanticColors>() ?? GarraSemanticColors.crema;

/// "Hoy" / "Mañana" / "sáb 10 oct" for a Lima wall-clock kickoff.
String footballDayLabel(DateTime kickoff) {
  final today = limaWallClock(DateTime.now());
  final day = DateTime(kickoff.year, kickoff.month, kickoff.day);
  final diff = day.difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Mañana';
  if (diff == -1) return 'Ayer';
  return _fmt('EEE d MMM').format(kickoff);
}

/// SONIC_05: a club tapped on a card / table / detail (opens Team Center).
typedef FootballTeamTap = void Function(int teamId, String name, String? crestUrl);

/// SONIC_04 Match Card V3: scoreboard. Left column = state (LIVE minute, PREMATCH
/// time, FINAL), right = two team lines with score. Featured team (provider id
/// via backend `featured`) gets the burgundy / cream / gold treatment.
class FootballMatchCard extends StatelessWidget {
  const FootballMatchCard({super.key, required this.match, required this.onTap,
    this.showCompetitionHeader = true, this.margin, this.onTeamTap});
  final FootballMatch match;
  final VoidCallback? onTap;
  final bool showCompetitionHeader;
  final EdgeInsetsGeometry? margin;
  /// SONIC_05: when set, crest + name of a club with a provider id open its Team Center.
  final FootballTeamTap? onTeamTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final garra = garraColors(context);
    final featured = match.featured;
    final competitionLine = [
      if (match.competition.isNotEmpty) match.competition,
      ?match.roundLabel,
    ].join(' · ');
    final header = showCompetitionHeader
        ? (competitionLine.isEmpty ? 'Competición' : competitionLine)
        : (match.roundLabel ?? '');
    final showScores = match.isLive || match.isFinished || match.homeScore != null;
    final homeWins = match.isFinished && (match.homeScore ?? 0) > (match.awayScore ?? 0);
    final awayWins = match.isFinished && (match.awayScore ?? 0) > (match.homeScore ?? 0);
    return Semantics(
      label: '${match.home} contra ${match.away}, ${match.statusLabel}',
      child: Card(
        margin: margin ?? const EdgeInsets.fromLTRB(16, 4, 16, 6),
        clipBehavior: Clip.antiAlias,
        color: featured ? Color.alphaBlend(garra.brandPrimary.withValues(alpha: 0.06),
            Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: featured
              ? BorderSide(color: garra.brandPrimary.withValues(alpha: 0.55), width: 1.2)
              : BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (featured) Container(width: 4, color: garra.brandPrestige),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (header.isNotEmpty || featured)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Expanded(
                            child: Text(header, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(
                                    color: featured ? garra.brandPrestige : null,
                                    fontWeight: featured ? FontWeight.w800 : FontWeight.w600)),
                          ),
                          if (featured)
                            Icon(Icons.star_rounded, size: 16, color: garra.brandPrestige),
                        ]),
                      ),
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      SizedBox(width: 62, child: _StateColumn(match: match)),
                      Container(width: 1, height: 44, margin: const EdgeInsets.only(right: 10),
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
                      Expanded(
                        child: Column(children: [
                          _TeamLine(name: match.home, crest: match.homeCrestUrl,
                              score: showScores ? match.homeScore : null, showScore: showScores,
                              strong: homeWins, live: match.isLive && !match.isUnconfirmed,
                              scoreKey: ValueKey('score_home_${match.id}'),
                              tapKey: ValueKey('team_tap_${match.id}_home'),
                              onTap: onTeamTap == null || match.homeId == null ? null
                                  : () => onTeamTap!(match.homeId!, match.home, match.homeCrestUrl)),
                          const SizedBox(height: 6),
                          _TeamLine(name: match.away, crest: match.awayCrestUrl,
                              score: showScores ? match.awayScore : null, showScore: showScores,
                              strong: awayWins, live: match.isLive && !match.isUnconfirmed,
                              scoreKey: ValueKey('score_away_${match.id}'),
                              tapKey: ValueKey('team_tap_${match.id}_away'),
                              onTap: onTeamTap == null || match.awayId == null ? null
                                  : () => onTeamTap!(match.awayId!, match.away, match.awayCrestUrl)),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.name, required this.crest, required this.score,
    required this.showScore, required this.strong, required this.live, required this.scoreKey,
    this.tapKey, this.onTap});
  final String name;
  final String? crest;
  final int? score;
  final bool showScore;
  final bool strong;
  final bool live;
  final Key scoreKey;
  final Key? tapKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final identity = Row(mainAxisSize: MainAxisSize.min, children: [
      FootballTeamCrest(name: name, url: crest, size: 24),
      const SizedBox(width: 8),
      Flexible(
        child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600, height: 1.15)),
      ),
    ]);
    return Row(children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          // Only crest + name open the club; the rest of the card keeps opening the match.
          child: onTap == null ? identity : Semantics(
            button: true,
            label: 'Ver club $name',
            child: InkWell(key: tapKey, borderRadius: BorderRadius.circular(8), onTap: onTap,
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: identity)),
          ),
        ),
      ),
      if (showScore)
        SizedBox(
          width: 28,
          child: Text(score == null ? '–' : '$score', key: scoreKey, textAlign: TextAlign.end,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900,
                  color: live ? garraColors(context).danger : null)),
        ),
    ]);
  }
}

/// LIVE → minute first (red); PREMATCH → time first; FINISHED → FINAL.
class _StateColumn extends StatelessWidget {
  const _StateColumn({required this.match});
  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final garra = garraColors(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget column(String top, String? bottom, {Color? color, bool dot = false}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Flexible(child: Text(top, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: color))),
        ]),
        if (bottom != null)
          Text(bottom, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: muted)),
      ],
    );
    if (match.isUnconfirmed) {
      return column(match.isLive ? 'En juego' : 'Por conf.', 'Actualizando', color: garra.warning);
    }
    if (match.isLive) {
      final minute = match.liveMinuteLabel;
      final top = switch (match.status) {
        'HALFTIME' => 'DESC.',
        'PENALTIES' => 'PEN.',
        'SUSPENDED' => 'SUSP.',
        _ => minute ?? 'VIVO',
      };
      return column(top, 'EN VIVO', color: garra.danger, dot: true);
    }
    if (match.isFinished) return column('FINAL', null, color: muted);
    final short = switch (match.status) {
      'POSTPONED' => 'POST.',
      'CANCELLED' => 'CANC.',
      _ => null,
    };
    if (short != null) return column(short, null, color: muted);
    final kickoff = match.kickoff;
    if (kickoff == null) return column('Por conf.', null, color: muted);
    return column(_fmt('HH:mm').format(kickoff), footballDayLabel(kickoff));
  }
}
