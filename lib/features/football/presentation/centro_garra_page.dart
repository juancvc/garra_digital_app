import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/connectivity_status.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/football_diagnostics.dart';
import '../data/garra_football_models.dart';
import '../data/garra_football_service.dart';
import 'football_match_card.dart';
import 'football_team_crest.dart';
import 'match_tribuna_section.dart';

final garraFootballServiceProvider = Provider<GarraFootballService>((ref) => GarraFootballService());

/// SONIC_01: Spanish (es_PE) dates like the rest of the app; falls back to the
/// default locale when es_PE data is not initialized (isolated widget tests).
DateFormat _footballFormat(String pattern) {
  try {
    return DateFormat(pattern, 'es_PE');
  } on Exception {
    return DateFormat(pattern);
  }
}

enum _Hub { forYou, peru, international }

extension on _Hub {
  String get label => switch (this) {
    _Hub.forYou => 'Para ti',
    _Hub.peru => 'Perú',
    _Hub.international => 'Internacional',
  };
}

enum _Section { today, live, upcoming, results, standings }

extension on _Section {
  String get label => switch (this) {
    _Section.today => 'Hoy',
    _Section.live => 'En vivo',
    _Section.upcoming => 'Próximos',
    _Section.results => 'Resultados',
    _Section.standings => 'Tabla',
  };
  FootballView? get view => switch (this) {
    _Section.today => FootballView.today,
    _Section.live => FootballView.live,
    _Section.upcoming => FootballView.upcoming,
    _Section.results => FootballView.results,
    _Section.standings => null,
  };
}

class CentroGarraPage extends ConsumerStatefulWidget {
  const CentroGarraPage({super.key});

  @override
  ConsumerState<CentroGarraPage> createState() => _CentroGarraPageState();
}

class _CentroGarraPageState extends ConsumerState<CentroGarraPage> {
  _Hub _hub = _Hub.forYou;
  _Section _section = _Section.today;
  String? _competition;
  List<FootballCompetition> _competitions = const [];
  final Map<String, FootballPage<FootballMatch>> _pages = {};
  final Map<String, FootballPage<Map<String, dynamic>>> _tables = {};
  bool _loading = false;
  bool _failed = false;
  FootballFailureLayer? _failureLayer;
  final _hubScroll = ScrollController();
  final _sectionScroll = ScrollController();
  final _competitionScroll = ScrollController();
  String get _pageKey => '${_section.name}:${_competition ?? 'ALL'}';

  bool get _nothingConfigured => _competitions.isNotEmpty &&
      !_competitions.any((competition) => competition.available);
  bool get _selectedUnconfigured => _competition != null &&
      !_competitions.any((c) => c.id == _competition && c.available);

  @override
  void dispose() {
    _hubScroll.dispose();
    _sectionScroll.dispose();
    _competitionScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  List<FootballCompetition> get _hubCompetitions {
    final available = _competitions.where((c) => c.available);
    return switch (_hub) {
      _Hub.peru => available.where((c) => c.isPeru).toList(),
      _Hub.international => available.where((c) => c.isInternational).toList(),
      _Hub.forYou => available.toList(),
    };
  }

  /// PARA TI: featured (by backend team id) first; else live; else the section list.
  List<FootballMatch> _visibleMatches(FootballPage<FootballMatch>? page) {
    final items = page?.items ?? const <FootballMatch>[];
    if (_hub != _Hub.forYou) return items;
    final featured = items.where((m) => m.featured).toList();
    if (featured.isNotEmpty) return featured;
    final live = items.where((m) => m.isLive).toList();
    return live.isNotEmpty ? live : items;
  }

  void _chooseHub(_Hub hub) {
    if (_hub == hub) return;
    setState(() {
      _hub = hub;
      _competition = null;
      _failed = false;
    });
    if (!_hasCurrentContent) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    final section = _section;
    final competition = _competition;
    final requestedKey = _pageKey;
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      if (mounted) setState(() => _failed = !_hasCurrentContent);
      return;
    }
    setState(() { _loading = true; _failed = false; });
    try {
      final service = ref.read(garraFootballServiceProvider);
      if (_competitions.isEmpty) _competitions = await service.competitions();
      if (!mounted) return;
      if (_nothingConfigured || _selectedUnconfigured) {
        if (section != _Section.standings) {
          _pages[requestedKey] = const FootballPage<FootballMatch>(
            items: [], stale: false, unavailable: true, partial: false);
        }
        setState(() {});
        return;
      }
      if (section == _Section.standings) {
        final id = competition ?? _competitions.where((c) => c.available).firstOrNull?.id;
        if (id != null) {
          final table = await service.standings(id);
          logFootballAnswer('standings:$id', table);
          _tables[id] = table;
        }
      } else {
        final page = await service.matches(section.view!, competition: competition);
        logFootballAnswer('matches:${section.view!.wire}:${competition ?? 'ALL'}', page);
        _pages[requestedKey] = page;
      }
      if (mounted) setState(() => _failureLayer = null);
    } catch (error) {
      logFootballFailure('${section.name}:${competition ?? 'ALL'}', error);
      if (mounted) setState(() { _failed = true; _failureLayer = footballFailureLayer(error); });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_pageKey != requestedKey && !_hasCurrentContent) _load();
      }
    }
  }

  bool get _hasCurrentContent => _section == _Section.standings
      ? _tables.containsKey(_competition ?? _competitions.where((c) => c.available).firstOrNull?.id)
      : _pages.containsKey(_pageKey);

  void _choose(_Section section) {
    if (_section == section) return;
    setState(() { _section = section; _failed = false; });
    if (!_hasCurrentContent) _load();
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(connectivityStatusProvider) == NetworkConnectivity.offline;
    final tableId = _competition ?? _competitions.where((c) => c.available).firstOrNull?.id;
    final page = _pages[_pageKey];
    final table = tableId == null ? null : _tables[tableId];
    final stale = _section == _Section.standings ? table?.stale == true : page?.stale == true;
    final partial = _section == _Section.standings ? table?.partial == true : page?.partial == true;
    final unavailable = _section == _Section.standings
        ? table?.unavailable == true : page?.unavailable == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Centro Garra')),
      body: Column(children: [
        SizedBox(height: 48, child: ListView(
          controller: _hubScroll, scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 28, 0),
          children: _Hub.values.map((hub) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: Text(hub.label),
              selected: _hub == hub, onSelected: (_) => _chooseHub(hub)),
          )).toList(),
        )),
        SizedBox(height: 50, child: Scrollbar(controller: _sectionScroll,
          thumbVisibility: true, child: ListView(
          controller: _sectionScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 28, 3),
          children: _Section.values.map((section) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: Text(section.label),
              selected: _section == section, onSelected: (_) => _choose(section)),
          )).toList(),
        ))),
        if (_hub != _Hub.forYou && _hubCompetitions.isNotEmpty)
          SizedBox(height: 50, child: Scrollbar(controller: _competitionScroll,
            thumbVisibility: true, child: ListView(controller: _competitionScroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 28, 3), children: [
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: const Text('Todas'), selected: _competition == null,
                onSelected: (_) { setState(() => _competition = null); _load(); })),
              ..._hubCompetitions.map((c) => Padding(padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(c.name), selected: _competition == c.id,
                  onSelected: (_) { setState(() => _competition = c.id); _load(); }))),
            ]))),
        if (((page?.items.isNotEmpty == true || table?.items.isNotEmpty == true) &&
            (offline || stale || partial || unavailable || _failed)) ||
            (_section != _Section.standings && page != null && page.items.isEmpty &&
                partial && !offline && !_failed))
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Text(offline ? 'Sin conexión · mostrando lo disponible' : _failed && _hasCurrentContent
              ? 'No pudimos actualizar · mostramos lo anterior' : stale
              ? 'Datos guardados · pueden estar desactualizados' : partial
              ? 'Algunas competiciones no están disponibles' : 'Fútbol temporalmente no disponible',
              style: Theme.of(context).textTheme.bodySmall)),
        Expanded(child: _body(page, table, offline)),
      ]),
    );
  }

  Widget _body(FootballPage<FootballMatch>? page,
      FootballPage<Map<String, dynamic>>? table, bool offline) {
    if (_loading && !_hasCurrentContent) {
      return const GarraHomeSkeleton();
    }
    if (_failed && !_hasCurrentContent) {
      final network = _failureLayer == FootballFailureLayer.appNetwork;
      return _notice(
        offline ? 'Sin conexión' : network ? 'No pudimos conectar con Garra' : 'No pudimos cargar el fútbol',
        offline ? 'Conéctate para consultar los partidos.'
            : network ? 'La conexión tardó demasiado o se interrumpió. Inténtalo de nuevo.'
            : 'Inténtalo de nuevo más tarde.',
        retry: !offline);
    }
    if (_section == _Section.standings) {
      if (table == null || table.items.isEmpty) {
        final unconfigured = _nothingConfigured || _selectedUnconfigured;
        // SONIC_01B: a competition without a published table is not an outage.
        final outage = table?.unavailable == true;
        return _notice(
          unconfigured ? 'Competiciones por activar'
              : outage ? 'Tabla temporalmente no disponible' : 'Tabla aún no disponible',
          unconfigured
              ? 'Las tablas estarán aquí cuando las competiciones estén disponibles.'
              : outage ? 'No pudimos traer la tabla. Inténtalo más tarde.'
              : 'Esta competición todavía no publica su tabla.',
          retry: !offline && !unconfigured && outage);
      }
      return RefreshIndicator(onRefresh: () => _load(refresh: true), child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              SizedBox(width: 36, child: Text('POS', style: Theme.of(context).textTheme.labelSmall)),
              const SizedBox(width: 40),
              Expanded(child: Text('EQUIPO', style: Theme.of(context).textTheme.labelSmall)),
              SizedBox(width: 36, child: Text('PJ', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
              SizedBox(width: 44, child: Text('DG', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
              SizedBox(width: 40, child: Text('PTS', textAlign: TextAlign.end, style: Theme.of(context).textTheme.labelSmall)),
            ]),
          ),
          ...table.items.map((row) {
            final featured = row['featured'] == true;
            final played = row['played'];
            final diff = row['goalDifference'];
            final dg = diff is num ? '${diff > 0 ? '+' : ''}$diff' : '–';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: featured
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: featured
                    ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35))
                    : null,
              ),
              child: Row(children: [
                SizedBox(width: 36, child: Text('${row['rank'] ?? '–'}',
                    style: const TextStyle(fontWeight: FontWeight.w800))),
                FootballTeamCrest(name: row['team']?.toString() ?? '?', url: row['crestUrl']?.toString(), size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(row['team']?.toString() ?? 'Equipo',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: featured ? FontWeight.w800 : FontWeight.w600))),
                SizedBox(width: 36, child: Text('${played ?? '–'}', textAlign: TextAlign.center)),
                SizedBox(width: 44, child: Text(dg, textAlign: TextAlign.center)),
                SizedBox(width: 40, child: Text('${row['points'] ?? '–'}', textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            );
          }),
        ]));
    }
    if (page == null || page.items.isEmpty) {
      final unconfigured = _nothingConfigured || _selectedUnconfigured;
      final outage = page?.unavailable == true;
      // SONIC_01B: a valid empty answer has its own copy per section; only a
      // real outage says the service is unavailable.
      final (emptyTitle, emptyMessage) = switch (_section) {
        _Section.live => ('Ningún partido en vivo ahora', 'Cuando empiece un partido lo verás aquí.'),
        _Section.upcoming => ('Sin partidos próximos', 'No hay partidos en los próximos 7 días.'),
        _Section.results => ('Sin resultados recientes', 'No hay resultados de los últimos 7 días.'),
        _ => ('Sin partidos hoy', 'No hay partidos programados para hoy en estas competiciones.'),
      };
      return _notice(
        unconfigured ? 'Competiciones por activar'
            : outage ? 'Fútbol temporalmente no disponible' : emptyTitle,
        offline ? 'Conéctate para consultar nuevos partidos.'
            : unconfigured ? 'Los partidos aparecerán cuando las competiciones estén disponibles.'
            : outage ? 'No pudimos traer los partidos. Inténtalo más tarde.'
            : emptyMessage,
        retry: !offline && !unconfigured && outage);
    }
    final items = _visibleMatches(page);
    if (items.isEmpty) {
      return _notice(
        _hub == _Hub.forYou ? 'Nada destacado por ahora' : 'No hay partidos aquí',
        _hub == _Hub.forYou
            ? 'Cuando tu equipo juegue o haya partidos en vivo, aparecerán aquí.'
            : 'Prueba otra sección o competición.',
        retry: false);
    }
    return RefreshIndicator(onRefresh: () => _load(refresh: true), child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(), itemCount: items.length,
      itemBuilder: (context, index) => FootballMatchCard(match: items[index],
        onTap: () => context.push('/centro-garra/partido/${items[index].id}?competition=${items[index].competitionId}',
          extra: items[index])),
    ));
  }

  Widget _notice(String title, String message, {required bool retry}) =>
      ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            if (retry) TextButton(onPressed: _load, child: const Text('Reintentar')),
          ]))),
      ]);
}

class CentroGarraMatchDetailPage extends ConsumerStatefulWidget {
  const CentroGarraMatchDetailPage({super.key, required this.match});
  final FootballMatch match;
  @override
  ConsumerState<CentroGarraMatchDetailPage> createState() => _CentroGarraMatchDetailPageState();
}

class _CentroGarraMatchDetailPageState extends ConsumerState<CentroGarraMatchDetailPage> {
  FootballDetail? _detail;
  bool _loading = true;
  bool _failed = false;
  final Map<String, List<Map<String, dynamic>>> _sections = {};
  final Set<String> _sectionLoading = {};
  final Set<String> _sectionFailed = {};

  @override
  void initState() { super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  Future<void> _load() async {
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      setState(() { _loading = false; _failed = _detail == null; }); return;
    }
    setState(() { _loading = true; _failed = false; });
    try {
      final result = await ref.read(garraFootballServiceProvider).detail(widget.match);
      if (mounted) setState(() { _detail = result; _failed = result == null; });
    } catch (error) {
      logFootballFailure('detail', error);
      if (mounted) setState(() => _failed = true);
    }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadSection(String section) async {
    if (_detail == null || _sections.containsKey(section) || _sectionLoading.contains(section)) return;
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      setState(() => _sectionFailed.add(section));
      return;
    }
    setState(() { _sectionLoading.add(section); _sectionFailed.remove(section); });
    try {
      final result = await ref.read(garraFootballServiceProvider).detail(widget.match, section: section);
      final items = switch (section) {
        'EVENTS' => result?.events,
        'LINEUPS' => result?.lineups,
        _ => result?.statistics,
      };
      if (!mounted) return;
      setState(() {
        if (items == null || (result!.partial && items.isEmpty)) {
          _sectionFailed.add(section);
        } else {
          _sections[section] = items;
        }
      });
    } catch (error) {
      logFootballFailure('detail:$section', error);
      if (mounted) setState(() => _sectionFailed.add(section));
    } finally {
      if (mounted) setState(() => _sectionLoading.remove(section));
    }
  }

  Widget _section(String title, String section) {
    final items = _sections[section];
    return ExpansionTile(
      title: Text(title),
      onExpansionChanged: (expanded) { if (expanded) _loadSection(section); },
      children: [
        if (_sectionLoading.contains(section)) const Padding(
          padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (_sectionFailed.contains(section)) ListTile(
          title: const Text('No pudimos cargar esta información'),
          trailing: TextButton(onPressed: () => _loadSection(section), child: const Text('Reintentar'))),
        if (items != null && items.isEmpty) const ListTile(title: Text('Sin datos disponibles')),
        if (items != null && section == 'STATISTICS')
          ..._statisticRows(items, _detail?.match ?? widget.match),
        if (items != null && section != 'STATISTICS') ...items.map((item) => switch (section) {
          'EVENTS' => ListTile(dense: true,
            leading: Icon(_eventIcon(item['type']?.toString())),
            title: Text(_eventTitle(item)),
            subtitle: Text([
              if ((item['player']?.toString() ?? '').isNotEmpty)
                footballEventLabel(item['type']?.toString(), detail: item['detail']?.toString()),
              if ((item['team']?.toString() ?? '').isNotEmpty) item['team'].toString(),
            ].join(' · ')),
            trailing: Text(_minute(item))),
          _ => ListTile(
            title: Text(item['team']?.toString() ?? 'Equipo'),
            subtitle: Text([
              if ((item['formation']?.toString() ?? '').isNotEmpty) 'Esquema ${item['formation']}',
              'Titulares: ${((item['starting'] as List?) ?? const []).join(' · ')}',
            ].join('\n'))),
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final match = detail?.match ?? widget.match;
    final text = Theme.of(context).textTheme;
    final competition = [
      if (match.competition.isNotEmpty) match.competition,
      ?match.roundLabel,
    ].join(' · ');
    return Scaffold(appBar: AppBar(title: const Text('Partido')),
      body: RefreshIndicator(onRefresh: _load, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16), children: [
          FootballMatchCard(match: match, onTap: null),
          Padding(padding: const EdgeInsets.fromLTRB(4, 2, 4, 6), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_stateLine(match), key: const ValueKey('match_state_line'),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700,
                  color: match.isLive ? Colors.red.shade700 : null)),
              if (competition.isNotEmpty) Text(competition, style: text.bodySmall),
            ])),
          if (_loading) const LinearProgressIndicator(),
          if (_failed) ListTile(title: const Text('No pudimos actualizar este partido'),
            trailing: TextButton(onPressed: _load, child: const Text('Reintentar'))),
          if (detail?.stale == true || detail?.partial == true) Padding(
            padding: const EdgeInsets.all(8), child: Text(detail!.stale
              ? 'Datos guardados · pueden estar desactualizados'
              : 'Algunos datos del partido aún no están disponibles')),
          const SizedBox(height: 4),
          Text('Resumen', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (detail != null) _section('Eventos', 'EVENTS'),
          if (detail != null) _section('Estadísticas', 'STATISTICS'),
          if (detail != null) _section('Alineaciones', 'LINEUPS'),
          const SizedBox(height: 8),
          MatchTribunaSection(match: match),
        ])));
  }

  /// Pre-match shows the Lima kickoff, LIVE the minute, finished the result.
  String _stateLine(FootballMatch match) {
    final kickoff = match.kickoff;
    return switch (match.status) {
      'LIVE' || 'FIRST_HALF' || 'HALFTIME' || 'SECOND_HALF' || 'EXTRA_TIME' || 'PENALTIES' =>
        match.statusLabel,
      'SUSPENDED' => 'Partido suspendido',
      'FINISHED' => match.homeScore != null && match.awayScore != null
          ? 'Final · ${match.home} ${match.homeScore} - ${match.awayScore} ${match.away}'
          : 'Final del partido',
      'POSTPONED' => 'Partido postergado',
      'CANCELLED' => 'Partido cancelado',
      'SCHEDULED' => kickoff == null ? 'Previa · horario por confirmar'
          : 'Previa · ${_footballFormat('EEE d MMM · HH:mm').format(kickoff)} (hora de Lima)',
      _ => 'Estado por confirmar',
    };
  }

  String _eventTitle(Map<String, dynamic> item) {
    final player = item['player']?.toString() ?? '';
    return player.isNotEmpty ? player
        : footballEventLabel(item['type']?.toString(), detail: item['detail']?.toString());
  }

  String _minute(Map<String, dynamic> item) {
    final elapsed = item['elapsed'];
    final extra = item['extra'];
    if (elapsed == null) return '–';
    return extra is num && extra > 0 ? "$elapsed+$extra′" : "$elapsed′";
  }

  /// One row per statistic: home value · label · away value.
  List<Widget> _statisticRows(List<Map<String, dynamic>> items, FootballMatch match) {
    final rows = <String, List<String?>>{};
    for (final item in items) {
      final type = item['type']?.toString() ?? '';
      final row = rows.putIfAbsent(type, () => [null, null]);
      final value = item['value']?.toString();
      if (item['team']?.toString() == match.away) {
        row[1] = value;
      } else {
        row[0] = value;
      }
    }
    return [
      for (final entry in rows.entries)
        ListTile(dense: true,
          leading: Text(entry.value[0] ?? '–'),
          title: Text(footballStatLabel(entry.key), textAlign: TextAlign.center),
          trailing: Text(entry.value[1] ?? '–')),
    ];
  }

  IconData _eventIcon(String? type) => switch (type) {
    'GOAL' => Icons.sports_soccer,
    'RED_CARD' => Icons.crop_portrait,
    'YELLOW_CARD' => Icons.crop_square,
    'SUBSTITUTION' => Icons.swap_horiz,
    _ => Icons.circle_outlined,
  };
}
