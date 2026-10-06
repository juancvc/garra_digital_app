import 'package:flutter/material.dart';

import '../data/garra_football_models.dart';
import 'football_match_card.dart';
import 'football_team_crest.dart';

/// SONIC_05 PARA TI hero: "PRÓXIMO PARTIDO DE `NAME`" with big crests, rival, local / visita,
/// competition + round, FULL date and Lima time, stadium and a "Ver partido" CTA. Nothing is
/// truncated: long names wrap. Previous / next matches are secondary, readable and tappable.
/// NAME comes from the config label or the provider team name — never hardcoded.
class FootballFeaturedHero extends StatelessWidget {
  const FootballFeaturedHero({super.key, required this.match, required this.kind, required this.name,
    required this.secondary, required this.onOpen, this.featuredTeamId, this.onTeamTap});
  final FootballMatch match;
  /// live | next | last
  final String kind;
  final String? name;
  final List<(String, FootballMatch)> secondary;
  final ValueChanged<FootballMatch> onOpen;
  final int? featuredTeamId;
  final FootballTeamTap? onTeamTap;

  @override
  Widget build(BuildContext context) {
    final garra = garraColors(context);
    final team = (name == null || name!.trim().isEmpty) ? 'TU EQUIPO' : name!.toUpperCase();
    final title = switch (kind) {
      'live' => '$team EN VIVO',
      'next' => 'PRÓXIMO PARTIDO DE $team',
      _ => 'ÚLTIMO PARTIDO',
    };
    final onBrand = garra.onBrand;
    final muted = onBrand.withValues(alpha: 0.82);
    final competitionLine = [
      if (match.competition.isNotEmpty) match.competition,
      ?match.roundLabel,
    ].join(' · ');
    final side = match.isHomeOf(featuredTeamId);
    return Container(
      key: const ValueKey('featured_hero'),
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [garra.brandPrimary, Color.lerp(garra.brandPrimary, Colors.black, 0.35)!]),
        border: Border.all(color: garra.brandPrestige.withValues(alpha: 0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (kind == 'live')
            Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8, top: 4),
                decoration: const BoxDecoration(color: Color(0xFFFF5252), shape: BoxShape.circle))
          else
            Padding(padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.star_rounded, size: 18, color: garra.brandPrestige)),
          Expanded(child: Text(title, key: const ValueKey('featured_hero_title'),
              style: TextStyle(color: onBrand, fontWeight: FontWeight.w900, letterSpacing: 0.6, fontSize: 13))),
        ]),
        if (competitionLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(competitionLine, key: const ValueKey('featured_hero_competition'),
              style: TextStyle(color: garra.brandPrestige, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _team(context, match.home, match.homeCrestUrl, match.homeId, 'home', onBrand),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: _center(context, onBrand, garra.brandPrestige)),
          _team(context, match.away, match.awayCrestUrl, match.awayId, 'away', onBrand),
        ]),
        if (side != null && kind != 'last') ...[
          const SizedBox(height: 8),
          Center(child: Container(
            key: const ValueKey('featured_hero_side'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
                border: Border.all(color: garra.brandPrestige.withValues(alpha: 0.8))),
            child: Text(side ? 'Juega de local' : 'Juega de visita',
                style: TextStyle(color: onBrand, fontSize: 11, fontWeight: FontWeight.w800)),
          )),
        ],
        const SizedBox(height: 10),
        _info(Icons.event_rounded, kind == 'last' && match.kickoff != null
                ? '${_cap(footballFullDate(match.kickoff!))} · ${footballClock(match.kickoff!)} (hora de Lima)'
                : footballKickoffLine(match), muted, key: 'featured_hero_date'),
        if (match.venue != null) _info(Icons.stadium_outlined, match.venue!, muted, key: 'featured_hero_venue'),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('featured_hero_cta'),
          style: FilledButton.styleFrom(backgroundColor: garra.brandPrestige,
              foregroundColor: Colors.black, visualDensity: VisualDensity.compact),
          onPressed: () => onOpen(match),
          child: const Text('Ver partido', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        for (final (label, m) in secondary) _secondary(context, label, m, onBrand),
      ]),
    );
  }

  static String _cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

  Widget _team(BuildContext context, String name, String? crest, int? id, String side, Color color) {
    final body = Column(children: [
      FootballTeamCrest(name: name, url: crest, size: 52),
      const SizedBox(height: 6),
      Text(name, textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14, height: 1.15)),
    ]);
    return Expanded(
      child: id == null || onTeamTap == null ? body : InkWell(
        key: ValueKey('featured_hero_team_$side'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTeamTap!(id, name, crest),
        child: body,
      ),
    );
  }

  Widget _center(BuildContext context, Color color, Color accent) {
    if (match.isLive || match.isFinished || match.homeScore != null) {
      final live = match.isLive && !match.isUnconfirmed;
      final style = TextStyle(color: live ? const Color(0xFFFF8A80) : color, fontSize: 30,
          fontWeight: FontWeight.w900);
      return Column(children: [
        Text('${match.homeScore ?? '–'} - ${match.awayScore ?? '–'}', key: const ValueKey('featured_hero_score'),
            style: style),
        Text(match.isFinished ? 'FINAL' : match.statusLabel, textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900)),
      ]);
    }
    final k = match.kickoff;
    return Column(children: [
      Text(k == null || match.isKickoffTentative ? 'vs' : footballClock(k), key: const ValueKey('featured_hero_time'),
          style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900)),
      if (match.status == 'POSTPONED')
        Text('POSTERGADO', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900))
      else if (k != null && !match.isKickoffTentative)
        Text(footballDayLabel(k), style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _info(IconData icon, String value, Color color, {required String key}) => Padding(
    key: ValueKey(key),
    padding: const EdgeInsets.only(top: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _secondary(BuildContext context, String label, FootballMatch m, Color color) {
    final garra = garraColors(context);
    return InkWell(
      key: ValueKey('featured_secondary_$label'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => onOpen(m),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            color: Colors.black.withValues(alpha: 0.18)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: TextStyle(color: garra.brandPrestige, fontWeight: FontWeight.w900,
                fontSize: 11, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            // One Text, wraps instead of "Universita…".
            Text(footballHeroLine(m), key: ValueKey('featured_secondary_text_$label'),
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, height: 1.2)),
          ])),
          Icon(Icons.chevron_right, size: 18, color: color),
        ]),
      ),
    );
  }
}

/// "Deportivo Garcilaso 4 - 0 Universitario · Final · domingo 11 de octubre" (never truncated).
String footballHeroLine(FootballMatch m) {
  final k = m.kickoff;
  final round = m.roundLabel == null ? '' : ' · ${m.roundLabel}';
  if (m.isFinished) {
    return '${m.home} ${m.homeScore ?? '–'} - ${m.awayScore ?? '–'} ${m.away} · Final'
        '${k == null ? '' : ' · ${footballFullDate(k)}'}$round';
  }
  if (m.status == 'UNKNOWN' && k != null && k.isBefore(limaWallClock(DateTime.now()))) {
    return '${m.home} vs ${m.away} · resultado por confirmar · ${footballFullDate(k)}$round';
  }
  final when = m.status == 'POSTPONED' ? 'postergado · nueva fecha por confirmar'
      : k == null ? 'fecha por confirmar'
      : m.kickoffConfirmed == false ? '${footballFullDate(k)} · hora por confirmar'
      : '${footballFullDate(k)} · ${footballClock(k)}';
  return '${m.home} vs ${m.away} · $when$round';
}
