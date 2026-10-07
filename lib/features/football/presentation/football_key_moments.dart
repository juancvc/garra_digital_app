import 'package:flutter/material.dart';

import '../data/garra_football_models.dart';
import 'football_match_card.dart';

/// SONIC_06 Match Center V6 "Momentos clave", under the score: goals, own goals, converted penalties, reds,
/// second yellows and decisive VAR. Home left / away right, chronological, the latest [visibleCount] shown
/// (a late winner is never hidden); "Ver todos los eventos (n)" opens the Eventos tab. The score is the
/// fixture's and is never derived from these moments; when they do not explain it yet, or the events
/// snapshot is stale, a discreet "Eventos actualizándose" is shown instead of inventing anything.
class FootballKeyMoments extends StatelessWidget {
  const FootballKeyMoments({super.key, required this.match, required this.events, required this.stale,
    required this.onShowAll, int? totalEvents}) : totalEvents = totalEvents ?? events.length;
  static const visibleCount = 3;
  final FootballMatch match;
  final List<Map<String, dynamic>> events;
  /// Provider events of the snapshot (all kinds), for "Ver todos los eventos (n)".
  final int totalEvents;
  final bool stale;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final moments = footballKeyMoments(events, match);
    final updating = stale || !footballMomentsExplainScore(match, moments);
    if (moments.isEmpty && !updating) return const SizedBox.shrink(key: ValueKey('key_moments_none'));
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final visible = moments.length <= visibleCount ? moments : moments.sublist(moments.length - visibleCount);
    return Padding(
      key: const ValueKey('key_moments'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('MOMENTOS CLAVE', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.8,
                  color: garraColors(context).brandPrestige))),
          if (updating)
            Flexible(child: Row(key: const ValueKey('events_updating'), mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sync, size: 12, color: muted),
              const SizedBox(width: 4),
              Flexible(child: Text('Eventos actualizándose', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: muted))),
            ])),
        ]),
        const SizedBox(height: 4),
        for (var i = 0; i < visible.length; i++)
          _MomentRow(key: ValueKey('key_moment_$i'), moment: visible[i]),
        if (moments.length > visibleCount)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: const ValueKey('key_moments_all'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: onShowAll,
              child: Text('Ver todos los eventos ($totalEvents)'),
            ),
          ),
      ]),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({super.key, required this.moment});
  final FootballKeyMoment moment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final away = moment.away;
    final line = Text('${moment.emoji} ${moment.minuteLabel} ${moment.label}',
        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: away ? TextAlign.end : TextAlign.start,
        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        if (away) const Spacer(),
        Flexible(flex: 3, child: line),
        if (!away) const Spacer(),
      ]),
    );
  }
}
