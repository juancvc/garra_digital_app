import 'package:flutter/material.dart';

import '../data/garra_football_models.dart';
import 'football_match_card.dart';

/// SONIC_04: premium event timeline — minute | semantic icon | player / team,
/// ordered by minute (extra time included). Home events on the left, away on
/// the right. Same-minute events are kept: double substitutions are real.
class FootballEventTimeline extends StatelessWidget {
  const FootballEventTimeline({super.key, required this.events, required this.match});
  final List<Map<String, dynamic>> events;
  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    final ordered = sortFootballEvents(events);
    return Column(children: [
      for (var i = 0; i < ordered.length; i++)
        _EventRow(key: ValueKey('event_$i'), event: ordered[i],
            away: ordered[i]['team']?.toString() == match.away && match.away != match.home),
    ]);
  }
}

String footballEventMinute(Map<String, dynamic> item) {
  final elapsed = item['elapsed'];
  final extra = item['extra'];
  if (elapsed == null) return '–';
  return extra is num && extra > 0 ? "$elapsed+$extra′" : "$elapsed′";
}

class _EventRow extends StatelessWidget {
  const _EventRow({super.key, required this.event, required this.away});
  final Map<String, dynamic> event;
  final bool away;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final type = event['type']?.toString();
    final detail = event['detail']?.toString();
    final kind = footballEventKind(type, detail: detail);
    final label = _label(kind, type, detail);
    final player = event['player']?.toString() ?? '';
    final assist = event['assist']?.toString() ?? '';
    final team = event['team']?.toString() ?? '';
    final title = player.isNotEmpty ? player : label;
    final second = [
      if (player.isNotEmpty) label,
      if (kind == FootballEventKind.substitution && assist.isNotEmpty) '⇄ $assist',
      if ((kind == FootballEventKind.goal || kind == FootballEventKind.penaltyGoal) && assist.isNotEmpty)
        'Asist. $assist',
      if (team.isNotEmpty) team,
    ].join(' · ');
    final content = Expanded(
      child: Column(
        crossAxisAlignment: away ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(title, textAlign: away ? TextAlign.end : TextAlign.start, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (second.isNotEmpty)
            Text(second, textAlign: away ? TextAlign.end : TextAlign.start, maxLines: 2,
                overflow: TextOverflow.ellipsis, style: text.bodySmall),
        ],
      ),
    );
    final minute = SizedBox(
      width: 48,
      child: Text(footballEventMinute(event), textAlign: away ? TextAlign.end : TextAlign.start,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
    );
    final icon = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: FootballEventIcon(kind: kind),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: away ? [content, icon, minute] : [minute, icon, content]),
    );
  }

  String _label(FootballEventKind kind, String? type, String? detail) => switch (kind) {
    FootballEventKind.secondYellow => 'Doble amarilla',
    FootballEventKind.videoReview => _varLabel(detail),
    _ => footballEventLabel(type, detail: detail),
  };

  String _varLabel(String? detail) {
    final d = detail?.toLowerCase() ?? '';
    if (d.contains('cancelled') || d.contains('disallowed')) return 'VAR · Gol anulado';
    if (d.contains('penalty confirmed')) return 'VAR · Penal confirmado';
    return 'Revisión VAR';
  }
}

/// Semantic icon + color per event kind (cards drawn as cards, not glyphs).
class FootballEventIcon extends StatelessWidget {
  const FootballEventIcon({super.key, required this.kind});
  final FootballEventKind kind;

  @override
  Widget build(BuildContext context) {
    final garra = garraColors(context);
    Widget card(Color color, {Color? behind}) => SizedBox(
      width: 22, height: 22,
      child: Stack(alignment: Alignment.center, children: [
        if (behind != null)
          Transform.translate(offset: const Offset(-3, -2), child: _card(behind)),
        Transform.translate(offset: behind == null ? Offset.zero : const Offset(3, 2),
            child: _card(color)),
      ]),
    );
    final (Widget child, String semantics) = switch (kind) {
      FootballEventKind.goal => (Icon(Icons.sports_soccer, size: 22, color: garra.success), 'Gol'),
      FootballEventKind.penaltyGoal => (Icon(Icons.sports_soccer, size: 22, color: garra.success), 'Gol de penal'),
      FootballEventKind.ownGoal => (Icon(Icons.sports_soccer, size: 22, color: garra.danger), 'Autogol'),
      FootballEventKind.missedPenalty => (Icon(Icons.block, size: 22, color: garra.textSecondary), 'Penal fallado'),
      FootballEventKind.yellow => (card(const Color(0xFFF2C230)), 'Tarjeta amarilla'),
      FootballEventKind.secondYellow => (card(const Color(0xFFC62828), behind: const Color(0xFFF2C230)), 'Doble amarilla'),
      FootballEventKind.red => (card(const Color(0xFFC62828)), 'Tarjeta roja'),
      FootballEventKind.substitution => (Icon(Icons.swap_vert_rounded, size: 22, color: garra.brandPrestige), 'Cambio'),
      FootballEventKind.videoReview => (Icon(Icons.videocam_outlined, size: 22, color: garra.textSecondary), 'VAR'),
      FootballEventKind.other => (Icon(Icons.info_outline, size: 20, color: garra.textSecondary), 'Incidencia'),
    };
    return Semantics(label: semantics, child: SizedBox(width: 24, height: 24, child: Center(child: child)));
  }

  Widget _card(Color color) => Container(
    width: 12, height: 16,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2),
        boxShadow: const [BoxShadow(blurRadius: 1, color: Color(0x33000000))]),
  );
}
