import 'package:flutter/material.dart';

import '../data/football_diagnostics.dart';
import '../data/garra_football_models.dart';
import 'football_match_card.dart';
import 'football_team_crest.dart';

/// SONIC_05 Team Center as a bottom sheet: generic for any provider team id (standings row, match
/// card or match detail). Data comes from the backend cache-only endpoint; no invented calendar.
Future<void> showFootballTeamCenter(BuildContext context, {required int teamId, required String name,
    String? crestUrl, required Future<FootballTeamCenterResult> Function() load,
    required ValueChanged<FootballMatch> onOpenMatch}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => FootballTeamCenterSheet(
      teamId: teamId, name: name, crestUrl: crestUrl, load: load,
      onOpenMatch: (match) {
        Navigator.of(sheetContext).pop();
        onOpenMatch(match);
      },
    ),
  );
}

enum FootballTeamFilter { all, upcoming, results }

extension on FootballTeamFilter {
  String get label => switch (this) {
    FootballTeamFilter.all => 'Todos',
    FootballTeamFilter.upcoming => 'Próximos',
    FootballTeamFilter.results => 'Resultados',
  };
}

/// Played (or awaiting its result) vs still to be played; cancelled only shows under "Todos".
bool _awaitingResult(FootballMatch m, DateTime limaNow) =>
    m.status == 'UNKNOWN' && m.kickoff != null && m.kickoff!.isBefore(limaNow);

bool footballTeamUpcoming(FootballMatch m, DateTime limaNow) =>
    m.isLive || (m.isPending && !_awaitingResult(m, limaNow));

bool footballTeamResult(FootballMatch m, DateTime limaNow) => m.isFinished || _awaitingResult(m, limaNow);

class FootballTeamCenterSheet extends StatefulWidget {
  const FootballTeamCenterSheet({super.key, required this.teamId, required this.name, this.crestUrl,
    required this.load, required this.onOpenMatch});
  final int teamId;
  final String name;
  final String? crestUrl;
  final Future<FootballTeamCenterResult> Function() load;
  final ValueChanged<FootballMatch> onOpenMatch;

  @override
  State<FootballTeamCenterSheet> createState() => _FootballTeamCenterSheetState();
}

class _FootballTeamCenterSheetState extends State<FootballTeamCenterSheet> {
  FootballTeamCenterResult? _result;
  bool _loading = true;
  bool _failed = false;
  FootballTeamFilter _filter = FootballTeamFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    try {
      final result = await widget.load();
      if (mounted) setState(() => _result = result);
    } catch (error) {
      logFootballFailure('team:${widget.teamId}', error);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        key: const ValueKey('team_center'),
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: _children(context),
      ),
    );
  }

  List<Widget> _children(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final center = _result?.center;
    final name = center?.name ?? widget.name;
    final crest = center?.crestUrl ?? widget.crestUrl;
    final header = Padding(
      key: const ValueKey('team_center_header'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(children: [
        FootballTeamCrest(name: name, url: crest, size: 56),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, key: const ValueKey('team_center_name'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
          if (center?.competition != null) ...[
            const SizedBox(height: 4),
            Text(center!.competition!, key: const ValueKey('team_center_competition'),
                style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ])),
      ]),
    );
    if (_loading && _result == null) {
      return [header, const Padding(padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(key: ValueKey('team_center_loading'))))];
    }
    if (_failed && _result == null) {
      return [header, _message(context, 'No pudimos cargar el club', 'Revisa tu conexión e inténtalo de nuevo.',
          key: 'team_center_error', retry: true)];
    }
    if (center == null) {
      final unavailable = _result?.unavailable == true || _result?.reason == 'CACHE';
      return [header, unavailable
          ? _message(context, 'Calendario aún no disponible',
              'Todavía no tenemos guardado el calendario de este club. Vuelve en unas horas.',
              key: 'team_center_unavailable', retry: true)
          : _message(context, 'Sin partidos en las competiciones activas',
              'Este club no tiene partidos en las competiciones que sigue Centro Garra.',
              key: 'team_center_empty')];
    }
    final limaNow = limaWallClock(DateTime.now());
    final matches = [...center.matches]..sort((a, b) =>
        (a.kickoff ?? DateTime(9999)).compareTo(b.kickoff ?? DateTime(9999)));
    final filtered = switch (_filter) {
      FootballTeamFilter.all => matches,
      FootballTeamFilter.upcoming => matches.where((m) => footballTeamUpcoming(m, limaNow)).toList(),
      FootballTeamFilter.results => matches.where((m) => footballTeamResult(m, limaNow)).toList(),
    };
    return [
      header,
      if (center.partial || _result?.stale == true)
        Padding(
          key: const ValueKey('team_center_partial'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Text(center.partial
              ? 'Algunas competiciones aún no tienen calendario guardado.'
              : 'Datos guardados · pueden estar desactualizados', style: text.bodySmall),
        ),
      if (center.live != null) ..._highlight(context, 'EN VIVO', center.live!, 'team_center_live'),
      _sectionLabel(context, 'PRÓXIMO'),
      center.next == null
          ? _inline(context, 'Sin próximo partido confirmado en el calendario guardado.', 'team_center_next_empty')
          : _card(center.next!, key: 'team_center_next'),
      _sectionLabel(context, 'ÚLTIMO'),
      center.last == null
          ? _inline(context, 'Aún no hay resultados en el calendario guardado.', 'team_center_last_empty')
          : _card(center.last!, key: 'team_center_last'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        child: Text('PARTIDOS', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      ),
      // Own line: the three filters never overflow on narrow phones or with large text.
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
        child: Wrap(spacing: 2, children: [
          for (final f in FootballTeamFilter.values) _filterTab(context, f),
        ]),
      ),
      if (filtered.isEmpty)
        _inline(context, switch (_filter) {
          FootballTeamFilter.upcoming => 'Sin partidos por jugar en el calendario guardado.',
          FootballTeamFilter.results => 'Sin resultados todavía.',
          FootballTeamFilter.all => 'Sin partidos en el calendario guardado.',
        }, 'team_center_list_empty')
      else
        for (final m in filtered) _card(m, key: 'team_center_match_${m.id}'),
    ];
  }

  List<Widget> _highlight(BuildContext context, String label, FootballMatch m, String key) =>
      [_sectionLabel(context, label), _card(m, key: key)];

  Widget _card(FootballMatch m, {required String key}) => FootballMatchCard(
      key: ValueKey(key), match: m, onTap: () => widget.onOpenMatch(m),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4));

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w900, letterSpacing: 0.8, color: garraColors(context).brandPrestige)),
  );

  Widget _inline(BuildContext context, String message, String key) => Padding(
    key: ValueKey(key),
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
    child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
  );

  Widget _filterTab(BuildContext context, FootballTeamFilter f) {
    final selected = f == _filter;
    final garra = garraColors(context);
    return InkWell(
      key: ValueKey('team_center_filter_${f.name}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _filter = f),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(f.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
              color: selected ? null : Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Container(height: 2, width: 18, color: selected ? garra.brandPrestige : Colors.transparent),
        ]),
      ),
    );
  }

  Widget _message(BuildContext context, String title, String message, {required String key, bool retry = false}) =>
      Padding(
        key: ValueKey(key),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            if (retry) TextButton(onPressed: _load, child: const Text('Reintentar')),
          ]))),
      );
}
