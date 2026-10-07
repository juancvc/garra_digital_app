import 'package:flutter/material.dart';

import '../data/football_diagnostics.dart';
import '../data/garra_football_models.dart';
import 'football_match_card.dart';
import 'football_team_crest.dart';

/// SONIC_05 Team Center as a bottom sheet: generic for any provider team id (standings row, match
/// card or match detail). Data comes from the backend cache-only endpoint; no invented calendar.
/// SONIC_06 V2: RESUMEN | PARTIDOS | TABLA. One scroll surface (the sheet's), tab content switched in
/// place: no nested scroll fighting the sheet drag.
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

enum FootballTeamTab { resumen, partidos, tabla }

extension on FootballTeamTab {
  String get label => switch (this) {
    FootballTeamTab.resumen => 'RESUMEN',
    FootballTeamTab.partidos => 'PARTIDOS',
    FootballTeamTab.tabla => 'TABLA',
  };
}

enum FootballTeamFilter { all, upcoming, results }

extension on FootballTeamFilter {
  String get label => switch (this) {
    FootballTeamFilter.all => 'Todos',
    FootballTeamFilter.upcoming => 'Próximos',
    FootballTeamFilter.results => 'Resultados',
  };
}

/// Played (or awaiting its result) vs still to be played.
bool _awaitingResult(FootballMatch m, DateTime limaNow) =>
    m.status == 'UNKNOWN' && m.kickoff != null && m.kickoff!.isBefore(limaNow);

bool footballTeamUpcoming(FootballMatch m, DateTime limaNow) =>
    m.isLive || (m.isPending && !_awaitingResult(m, limaNow));

bool footballTeamResult(FootballMatch m, DateTime limaNow) => m.isFinished || _awaitingResult(m, limaNow);

/// SONIC_06: every fixture in exactly one list. The backend split (upcoming by date, a postponed fixture by
/// its round; results newest first) wins; an older backend answer is split on the device.
({List<FootballMatch> upcoming, List<FootballMatch> results}) footballTeamSplit(
    FootballTeamCenter center, DateTime limaNow) {
  if (center.upcoming.isNotEmpty || center.results.isNotEmpty) {
    return (upcoming: center.upcoming, results: center.results);
  }
  final far = DateTime(9999);
  final upcoming = center.matches.where((m) => footballTeamUpcoming(m, limaNow)).toList()
    ..sort((a, b) {
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      return (a.kickoff ?? far).compareTo(b.kickoff ?? far);
    });
  final ids = {for (final m in upcoming) m.id};
  final results = center.matches.where((m) => !ids.contains(m.id)).toList()
    ..sort((a, b) => (b.kickoff ?? DateTime(0)).compareTo(a.kickoff ?? DateTime(0)));
  return (upcoming: upcoming, results: results);
}

const _monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre',
  'Octubre', 'Noviembre', 'Diciembre'];
const _monthShort = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SET', 'OCT', 'NOV', 'DIC'];

/// Month group of a fixture; a postponed fixture without a new date has no month of its own.
String footballTeamMonth(FootballMatch m, {required int currentYear}) {
  final k = m.kickoff;
  if (m.status == 'POSTPONED' || k == null) return 'Por reprogramar';
  final name = _monthNames[k.month - 1];
  return k.year == currentYear ? name : '$name ${k.year}';
}

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
  static const _switch = Duration(milliseconds: 180);
  FootballTeamCenterResult? _result;
  bool _loading = true;
  bool _failed = false;
  FootballTeamTab _tab = FootballTeamTab.resumen;
  FootballTeamFilter _filter = FootballTeamFilter.all;
  bool _fullTable = false;

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

  String _opponent(FootballMatch m) => switch (m.isHomeOf(widget.teamId)) {
    true => 'vs ${m.away}',
    false => 'en ${m.home}',
    null => '${m.home} vs ${m.away}',
  };

  String _shortDate(FootballMatch m) {
    final k = m.kickoff;
    if (m.status == 'POSTPONED') return 'postergado';
    if (k == null) return 'fecha por confirmar';
    return '${k.day} ${_monthShort[k.month - 1].toLowerCase()}';
  }

  List<Widget> _children(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final center = _result?.center;
    final name = center?.name ?? widget.name;
    final crest = center?.crestUrl ?? widget.crestUrl;
    final next = center?.live ?? center?.next;
    final last = center?.last;
    final header = Padding(
      key: const ValueKey('team_center_header'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FootballTeamCrest(name: name, url: crest, size: 56),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, key: const ValueKey('team_center_name'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
          if (center?.competition != null) ...[
            const SizedBox(height: 4),
            Text(center!.competition!, key: const ValueKey('team_center_competition'),
                style: text.bodyMedium?.copyWith(color: muted)),
          ],
          if (next != null) ...[
            const SizedBox(height: 4),
            Text('${center?.live != null ? 'En vivo' : 'Próximo'}: ${_opponent(next)} · '
                '${next.isLive ? next.statusLabel : _shortDate(next)}',
                key: const ValueKey('team_center_header_next'), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
          if (last != null)
            Text('Último: ${last.homeScore ?? '–'}-${last.awayScore ?? '–'} ${_opponent(last)}',
                key: const ValueKey('team_center_header_last'), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(color: muted)),
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
    final split = footballTeamSplit(center, limaNow);
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
      _tabs(context),
      AnimatedSwitcher(
        duration: _switch,
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter,
            children: [...previous.map((w) => Offstage(child: w)), ?current]),
        child: KeyedSubtree(
          key: ValueKey('team_center_body_${_tab.name}_${_filter.name}_$_fullTable'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: switch (_tab) {
            FootballTeamTab.resumen => _resumen(context, center, split.upcoming),
            FootballTeamTab.partidos => _partidos(context, split.upcoming, split.results, limaNow.year),
            FootballTeamTab.tabla => _tabla(context, center.standings),
          }),
        ),
      ),
    ];
  }

  Widget _tabs(BuildContext context) {
    final garra = garraColors(context);
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)))),
      child: Row(children: [
        for (final t in FootballTeamTab.values)
          Expanded(child: InkWell(
            key: ValueKey('team_center_tab_${t.name}'),
            onTap: () => setState(() => _tab = t),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 3,
                  color: t == _tab ? garra.brandPrestige : Colors.transparent))),
              child: Text(t.label, maxLines: 1, style: text.labelLarge?.copyWith(letterSpacing: 0.6,
                  fontWeight: t == _tab ? FontWeight.w900 : FontWeight.w600,
                  color: t == _tab ? null : Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          )),
      ]),
    );
  }

  List<Widget> _resumen(BuildContext context, FootballTeamCenter center, List<FootballMatch> upcoming) {
    final shown = {center.live?.id, center.next?.id};
    final soon = upcoming.where((m) => !shown.contains(m.id)).take(3).toList();
    return [
      if (center.live != null) ...[_sectionLabel(context, 'EN VIVO'), _card(center.live!, key: 'team_center_live')],
      _sectionLabel(context, 'PRÓXIMO'),
      center.next == null
          ? _inline(context, 'Sin próximo partido confirmado en el calendario guardado.', 'team_center_next_empty')
          : _card(center.next!, key: 'team_center_next'),
      _sectionLabel(context, 'ÚLTIMO'),
      center.last == null
          ? _inline(context, 'Aún no hay resultados en el calendario guardado.', 'team_center_last_empty')
          : _card(center.last!, key: 'team_center_last'),
      if (soon.isNotEmpty) ...[
        _sectionLabel(context, 'PRÓXIMOS PARTIDOS'),
        for (final m in soon) _row(m, key: 'team_center_soon_${m.id}'),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: TextButton.icon(
            key: const ValueKey('team_center_calendar'),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Ver calendario'),
            onPressed: () => setState(() { _tab = FootballTeamTab.partidos; _filter = FootballTeamFilter.all; }),
          ),
        ),
      ),
    ];
  }

  List<Widget> _partidos(BuildContext context, List<FootballMatch> upcoming, List<FootballMatch> results,
      int year) {
    List<Widget> grouped(List<FootballMatch> list, String section) {
      final out = <Widget>[];
      String? month;
      for (final m in list) {
        final label = footballTeamMonth(m, currentYear: year);
        if (label != month) {
          month = label;
          out.add(Padding(
            key: ValueKey('team_center_month_${section}_$label'),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
            child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ));
        }
        out.add(_row(m, key: 'team_center_match_${m.id}'));
      }
      return out;
    }
    final showUpcoming = _filter != FootballTeamFilter.results;
    final showResults = _filter != FootballTeamFilter.upcoming;
    return [
      // Own line: the three filters never overflow on narrow phones or with large text.
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
        child: Wrap(spacing: 2, children: [
          for (final f in FootballTeamFilter.values) _filterTab(context, f),
        ]),
      ),
      if (showUpcoming) ...[
        if (_filter == FootballTeamFilter.all)
          _sectionLabel(context, 'PRÓXIMOS', key: 'team_center_section_upcoming'),
        if (upcoming.isEmpty)
          _inline(context, 'Sin partidos por jugar en el calendario guardado.', 'team_center_upcoming_empty')
        else
          ...grouped(upcoming, 'up'),
      ],
      if (showResults) ...[
        if (_filter == FootballTeamFilter.all)
          _sectionLabel(context, 'RESULTADOS', key: 'team_center_section_results'),
        if (results.isEmpty)
          _inline(context, 'Sin resultados todavía.', 'team_center_results_empty')
        else
          ...grouped(results, 'res'),
      ],
    ];
  }

  List<Widget> _tabla(BuildContext context, FootballTeamStandings? standings) {
    final text = Theme.of(context).textTheme;
    final rows = standings?.groupRows ?? const <Map<String, dynamic>>[];
    final index = rows.indexWhere((r) => (r['teamId'] as num?)?.toInt() == widget.teamId);
    if (standings == null || rows.isEmpty || index < 0) {
      return [_inline(context, 'Tabla aún no disponible para este club.', 'team_center_table_empty')];
    }
    final start = (index - 2).clamp(0, rows.length);
    final end = (index + 3).clamp(0, rows.length);
    final windowed = start > 0 || end < rows.length;
    final visible = _fullTable ? rows : rows.sublist(start, end);
    final title = [?standings.competition, if (standings.group != null) footballStageLabel(standings.group)]
        .join(' · ');
    return [
      if (title.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(title, key: const ValueKey('team_center_table_title'),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
        child: Row(children: [
          const SizedBox(width: 26),
          const Expanded(child: SizedBox()),
          for (final h in ['PJ', 'DG', 'PTS'])
            SizedBox(width: 36, child: Text(h, textAlign: TextAlign.end, style: text.labelSmall)),
        ]),
      ),
      AnimatedSize(
        duration: _switch,
        alignment: Alignment.topCenter,
        child: Column(children: [for (final r in visible) _tableRow(context, r)]),
      ),
      if (windowed)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: TextButton(
              key: const ValueKey('team_center_table_toggle'),
              onPressed: () => setState(() => _fullTable = !_fullTable),
              child: Text(_fullTable ? 'Ver menos' : 'Ver tabla completa (${rows.length})'),
            ),
          ),
        ),
      if (standings.stale)
        _inline(context, 'Datos guardados · pueden estar desactualizados', 'team_center_table_stale'),
    ];
  }

  Widget _tableRow(BuildContext context, Map<String, dynamic> r) {
    final text = Theme.of(context).textTheme;
    final id = (r['teamId'] as num?)?.toInt();
    final mine = id == widget.teamId;
    final name = r['team']?.toString() ?? 'Equipo';
    final style = text.bodyMedium?.copyWith(fontWeight: mine ? FontWeight.w900 : FontWeight.w500);
    String n(String k) => (r[k] as num?)?.toString() ?? '–';
    return Container(
      key: ValueKey('team_center_table_row_${id ?? name}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: mine ? garraColors(context).brandPrimary.withValues(alpha: 0.10) : null,
      ),
      child: Row(children: [
        SizedBox(width: 26, child: Text(n('rank'), style: style)),
        FootballTeamCrest(name: name, url: footballCrestUrl(r['crestUrl']), size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        SizedBox(width: 36, child: Text(n('played'), textAlign: TextAlign.end, style: style)),
        SizedBox(width: 36, child: Text(n('goalDifference'), textAlign: TextAlign.end, style: style)),
        SizedBox(width: 36, child: Text(n('points'), textAlign: TextAlign.end,
            style: style?.copyWith(fontWeight: FontWeight.w900))),
      ]),
    );
  }

  /// Compact fixture row: date | opponent | state (EN VIVO / FINAL / POSTERGADO / POR CONFIRMAR / hour).
  Widget _row(FootballMatch m, {required String key}) => Builder(builder: (context) {
    final text = Theme.of(context).textTheme;
    final garra = garraColors(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final k = m.kickoff;
    final home = m.isHomeOf(widget.teamId);
    final rival = home == false ? m.home : m.away;
    final rivalCrest = home == false ? m.homeCrestUrl : m.awayCrestUrl;
    final limaNow = limaWallClock(DateTime.now());
    final postponed = m.status == 'POSTPONED';
    final (String state, Color? color) = m.isLive
        ? (m.liveMinuteLabel == null ? 'EN VIVO' : 'EN VIVO · ${m.liveMinuteLabel}', garra.danger)
        : m.isFinished ? ('FINAL ${m.homeScore ?? '–'}-${m.awayScore ?? '–'}', null)
        : postponed ? ('POSTERGADO', garra.warning)
        : m.status == 'CANCELLED' ? ('CANCELADO', muted)
        : _awaitingResult(m, limaNow) || m.isUnconfirmed ? ('POR CONFIRMAR', garra.warning)
        : k == null || m.kickoffConfirmed == false ? ('Hora por confirmar', muted)
        : (footballClock(k), null);
    final subtitle = [
      home == null ? null : home ? 'Local' : 'Visita',
      ?m.roundLabel,
      if (m.competition.isNotEmpty) m.competition,
    ].whereType<String>().join(' · ');
    return InkWell(
      key: ValueKey(key),
      onTap: () => widget.onOpenMatch(m),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
        child: Row(children: [
          SizedBox(width: 44, child: postponed || k == null
              ? Text('—', textAlign: TextAlign.center, style: text.titleMedium)
              : Column(children: [
                  Text('${k.day}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1)),
                  Text(_monthShort[k.month - 1], style: text.labelSmall),
                ])),
          const SizedBox(width: 10),
          FootballTeamCrest(name: rival, url: rivalCrest, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(home == null ? '${m.home} vs ${m.away}' : rival, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (postponed)
              Text('Postergado · nueva fecha por confirmar', key: ValueKey('team_center_pst_${m.id}'),
                  maxLines: 2, style: text.bodySmall?.copyWith(color: garra.warning))
            else if (subtitle.isNotEmpty)
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
          ])),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(state, key: ValueKey('${key}_state'), textAlign: TextAlign.end, maxLines: 2,
                overflow: TextOverflow.ellipsis, style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900, color: color)),
          ),
        ]),
      ),
    );
  });

  Widget _card(FootballMatch m, {required String key}) => FootballMatchCard(
      key: ValueKey(key), match: m, onTap: () => widget.onOpenMatch(m),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4));

  Widget _sectionLabel(BuildContext context, String label, {String? key}) => Padding(
    key: key == null ? null : ValueKey(key),
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
