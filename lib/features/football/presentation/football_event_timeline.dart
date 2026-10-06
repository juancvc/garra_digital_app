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
    final goal = kind == FootballEventKind.goal || kind == FootballEventKind.penaltyGoal
        || kind == FootballEventKind.ownGoal;
    // SONIC_05: goals stand out with a tinted row; other events stay on the plain surface.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: goal ? BoxDecoration(borderRadius: BorderRadius.circular(12),
          color: footballEventColor(context, kind).withValues(alpha: 0.10)) : null,
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

/// SONIC_05: strong semantic color per event kind (goal green, cards yellow / red, sub blue,
/// VAR violet) — distinct at a glance in light and dark themes.
Color footballEventColor(BuildContext context, FootballEventKind kind) {
  final garra = garraColors(context);
  return switch (kind) {
    FootballEventKind.goal || FootballEventKind.penaltyGoal => const Color(0xFF1E9E4A),
    FootballEventKind.ownGoal => garra.danger,
    FootballEventKind.missedPenalty => garra.textSecondary,
    FootballEventKind.yellow => const Color(0xFFF2C230),
    FootballEventKind.secondYellow || FootballEventKind.red => const Color(0xFFD32F2F),
    FootballEventKind.substitution => const Color(0xFF1E88E5),
    FootballEventKind.videoReview => const Color(0xFF7E57C2),
    FootballEventKind.other => garra.textSecondary,
  };
}

/// Semantic icon + color per event kind (cards drawn as cards, not glyphs), on a tinted disc.
class FootballEventIcon extends StatelessWidget {
  const FootballEventIcon({super.key, required this.kind});
  final FootballEventKind kind;

  @override
  Widget build(BuildContext context) {
    final color = footballEventColor(context, kind);
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
      FootballEventKind.goal => (Icon(Icons.sports_soccer, size: 20, color: color), 'Gol'),
      FootballEventKind.penaltyGoal => (Icon(Icons.sports_soccer, size: 20, color: color), 'Gol de penal'),
      FootballEventKind.ownGoal => (Icon(Icons.sports_soccer, size: 20, color: color), 'Autogol'),
      FootballEventKind.missedPenalty => (Icon(Icons.block, size: 20, color: color), 'Penal fallado'),
      FootballEventKind.yellow => (card(const Color(0xFFF2C230)), 'Tarjeta amarilla'),
      FootballEventKind.secondYellow => (card(const Color(0xFFD32F2F), behind: const Color(0xFFF2C230)), 'Doble amarilla'),
      FootballEventKind.red => (card(const Color(0xFFD32F2F)), 'Tarjeta roja'),
      FootballEventKind.substitution => (Icon(Icons.swap_vert_rounded, size: 20, color: color), 'Cambio'),
      FootballEventKind.videoReview => (Text('VAR', style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w900, letterSpacing: 0.2)), 'VAR'),
      FootballEventKind.other => (Icon(Icons.info_outline, size: 18, color: color), 'Incidencia'),
    };
    return Semantics(label: semantics, child: Container(
      key: ValueKey('event_icon_${kind.name}'),
      width: 32, height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16),
          border: Border.all(color: color.withValues(alpha: 0.55))),
      child: child,
    ));
  }

  Widget _card(Color color) => Container(
    width: 12, height: 16,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2),
        boxShadow: const [BoxShadow(blurRadius: 1, color: Color(0x33000000))]),
  );
}
