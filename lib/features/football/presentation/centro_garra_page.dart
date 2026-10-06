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

class _CentroGarraPageState extends ConsumerState<CentroGarraPage>
    with AutomaticKeepAliveClientMixin {
  _Hub _hub = _Hub.forYou;
  _Section _section = _Section.today;
  String? _competition;
  String? _standingStage;
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

  @override
  bool get wantKeepAlive => true;

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

  List<FootballMatch> _visibleMatches(FootballPage<FootballMatch> page) {
    final items = page.items;
    if (_hub != _Hub.forYou) return items;
    final featured = items.where((m) => m.featured).toList();
    final live = items.where((m) => m.isLive && !m.featured).toList();
    if (featured.isEmpty && live.isEmpty) return items;
    return [...featured, ...live];
  }

  /// Group by competition, chronological within each group.
  List<({String? header, FootballMatch? match})> _groupedRows(List<FootballMatch> items) {
    final sorted = [...items]..sort((a, b) {
      final byComp = a.competition.compareTo(b.competition);
      if (byComp != 0) return byComp;
      final ak = a.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bk = b.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ak.compareTo(bk);
    });
    final rows = <({String? header, FootballMatch? match})>[];
    String? last;
    for (final m in sorted) {
      final key = m.competition.isEmpty ? 'Competición' : m.competition;
      if (key != last) {
        rows.add((header: key, match: null));
        last = key;
      }
      rows.add((header: null, match: m));
    }
    return rows;
  }

  void _chooseHub(_Hub hub) {
    if (_hub == hub) return;
    setState(() {
      _hub = hub;
      _competition = null;
      _standingStage = null;
    });
    _load();
  }

  void _chooseSection(_Section section) {
    if (_section == section) return;
    setState(() {
      _section = section;
      _standingStage = null;
    });
    _load();
  }

  void _chooseCompetition(String? id) {
    if (_competition == id) return;
    setState(() {
      _competition = id;
      _standingStage = null;
    });
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      setState(() {
        _loading = false;
        _failed = !_hasCurrentContent;
        _failureLayer = FootballFailureLayer.appNetwork;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
      _failureLayer = null;
    });
    try {
      final service = ref.read(garraFootballServiceProvider);
      if (_competitions.isEmpty || refresh) {
        _competitions = await service.competitions();
      }
      final section = _section;
      if (section != _Section.standings) {
        final view = section.view!;
        final page = await service.matches(view, competition: _competition);
        logFootballAnswer('${view.wire}:${_competition ?? 'ALL'}', page);
        if (mounted) setState(() => _pages[_pageKey] = page);
      }
      if (section == _Section.standings) {
        final id = _competition ?? _hubCompetitions.where((c) => c.available).map((c) => c.id).firstOrNull
            ?? _competitions.where((c) => c.available).map((c) => c.id).firstOrNull;
        if (id != null) {
          final table = await service.standings(id);
          logFootballAnswer('standings:$id', table);
          if (mounted) {
            setState(() {
              _competition ??= id;
              _tables[id] = table;
              final stages = FootballStandingStage.fromRows(table.items);
              if (_standingStage == null || !stages.any((s) => s.name == _standingStage)) {
                _standingStage = stages.isEmpty ? null : stages.first.name;
              }
            });
          }
        }
      }
    } catch (error) {
      logFootballFailure(_pageKey, error);
      if (mounted) {
        setState(() {
          _failed = true;
          _failureLayer = footballFailureLayer(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasCurrentContent => _section == _Section.standings
      ? _tables.containsKey(_competition)
      : _pages.containsKey(_pageKey);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final offline = ref.watch(connectivityStatusProvider) == NetworkConnectivity.offline;
    final page = _pages[_pageKey];
    final table = _competition == null ? null : _tables[_competition];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro Garra'),
        actions: [
          IconButton(
            key: const ValueKey('chat_futbolero_entry'),
            tooltip: 'Chat Futbolero',
            icon: const Icon(Icons.sports_soccer),
            onPressed: () => context.push('/centro-garra/chat-futbolero'),
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            controller: _hubScroll, scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _Hub.values.map((hub) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(hub.label),
                selected: _hub == hub, onSelected: (_) => _chooseHub(hub)),
            )).toList(),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            controller: _sectionScroll, scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _Section.values.map((section) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(section.label),
                selected: _section == section, onSelected: (_) => _chooseSection(section)),
            )).toList(),
          ),
        ),
        if (_hub != _Hub.forYou && _hubCompetitions.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              controller: _competitionScroll, scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              children: [
                Padding(padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: const Text('Todas'),
                    selected: _competition == null,
                    onSelected: (_) => _chooseCompetition(null))),
                ..._hubCompetitions.map((c) => Padding(padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.name, style: TextStyle(
                      color: c.available ? null : Theme.of(context).disabledColor)),
                    selected: _competition == c.id,
                    onSelected: c.available ? (_) => _chooseCompetition(c.id) : null,
                  ))),
              ],
            ),
          ),
        if (_loading && !_hasCurrentContent) const LinearProgressIndicator(),
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
      return _standingsBody(table, offline);
    }
    if (page == null || page.items.isEmpty) {
      final unconfigured = _nothingConfigured || _selectedUnconfigured;
      final outage = page?.unavailable == true;
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
    final rows = _groupedRows(items);
    return RefreshIndicator(onRefresh: () => _load(refresh: true), child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.header != null) {
          return Padding(
            key: ValueKey('comp_header_${row.header}'),
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
            child: Text(row.header!, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800)),
          );
        }
        final match = row.match!;
        return FootballMatchCard(
          key: ValueKey('match_${match.id}'),
          match: match,
          showCompetitionHeader: false,
          onTap: () => context.push(
            '/centro-garra/partido/${match.id}?competition=${match.competitionId}',
            extra: match),
        );
      },
    ));
  }

  Widget _standingsBody(FootballPage<Map<String, dynamic>>? table, bool offline) {
    if (table == null || table.items.isEmpty) {
      final unconfigured = _nothingConfigured || _selectedUnconfigured;
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
    final stages = FootballStandingStage.fromRows(table.items);
    final stageName = _standingStage ?? stages.first.name;
    final stage = stages.firstWhere((s) => s.name == stageName, orElse: () => stages.first);
    return RefreshIndicator(onRefresh: () => _load(refresh: true), child: ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (stages.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: stages.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey('stage_${s.name}'),
                  label: Text(s.name),
                  selected: s.name == stage.name,
                  onSelected: (_) => setState(() => _standingStage = s.name),
                ),
              )).toList(),
            ),
          ),
        if (stages.length == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(stage.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800)),
          ),
        const SizedBox(height: 4),
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
        ...stage.rows.map((row) {
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
              Expanded(child: Text(row['team']?.toString() ?? 'Equipo', maxLines: 2,
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

class _CentroGarraMatchDetailPageState extends ConsumerState<CentroGarraMatchDetailPage>
    with SingleTickerProviderStateMixin {
  FootballDetail? _detail;
  bool _loading = true;
  bool _failed = false;
  final Map<String, List<Map<String, dynamic>>> _sections = {};
  final Set<String> _sectionLoading = {};
  final Set<String> _sectionFailed = {};
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    _syncTabs();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      setState(() { _loading = false; _failed = _detail == null; }); return;
    }
    setState(() { _loading = true; _failed = false; });
    try {
      final result = await ref.read(garraFootballServiceProvider).detail(widget.match);
      if (mounted) setState(() { _detail = result; _failed = result == null; _syncTabs(); });
    } catch (error) {
      logFootballFailure('detail', error);
      if (mounted) setState(() => _failed = true);
    }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _syncTabs() {
    final labels = _tabLabels();
    if (_tabs == null || _tabs!.length != labels.length) {
      _tabs?.dispose();
      _tabs = TabController(length: labels.length, vsync: this);
      _tabs!.addListener(() {
        if (_tabs!.indexIsChanging) return;
        _ensureTabLoaded(_tabs!.index);
      });
    }
  }

  void _ensureTabLoaded(int index) {
    final labels = _tabLabels();
    if (index < 0 || index >= labels.length) return;
    final label = labels[index];
    if (label == 'Eventos') _loadSection('EVENTS');
    if (label == 'Alineaciones') _loadSection('LINEUPS');
    if (label == 'Estadísticas') _loadSection('STATISTICS');
  }

  List<String> _tabLabels() {
    final match = _detail?.match ?? widget.match;
    final prematch = match.isPrematch || match.isScheduled;
    if (prematch) {
      return ['Resumen', 'Alineaciones', 'Tribuna'];
    }
    return ['Resumen', 'Eventos', 'Alineaciones', 'Estadísticas', 'Tribuna'];
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

  Widget _lazySection(String section, {required Widget Function(List<Map<String, dynamic>>) builder}) {
    final items = _sections[section];
    if (_sectionLoading.contains(section)) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (_sectionFailed.contains(section)) {
      return ListTile(
        title: const Text('No pudimos cargar esta información'),
        trailing: TextButton(onPressed: () => _loadSection(section), child: const Text('Reintentar')));
    }
    if (items == null) {
      return ListTile(
        title: const Text('Toca para cargar'),
        trailing: TextButton(onPressed: () => _loadSection(section), child: const Text('Cargar')));
    }
    if (items.isEmpty) return const ListTile(title: Text('Sin datos disponibles'));
    return builder(items);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final match = detail?.match ?? widget.match;
    final text = Theme.of(context).textTheme;
    final labels = _tabLabels();
    return Scaffold(
      appBar: AppBar(title: const Text('Partido')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: FootballMatchCard(match: match, onTap: null),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_stateLine(match), key: const ValueKey('match_state_line'),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700,
                color: match.isLive ? Colors.red.shade700 : null)),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_failed) ListTile(title: const Text('No pudimos actualizar este partido'),
          trailing: TextButton(onPressed: _load, child: const Text('Reintentar'))),
        if (detail?.stale == true || detail?.partial == true) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(detail!.stale
            ? 'Datos guardados · pueden estar desactualizados'
            : 'Algunos datos del partido aún no están disponibles')),
        if (_tabs != null) TabBar(
          controller: _tabs,
          isScrollable: true,
          onTap: _ensureTabLoaded,
          tabs: [for (final label in labels) Tab(text: label)],
        ),
        if (_tabs != null) Expanded(
          child: TabBarView(controller: _tabs, children: [
            for (final label in labels) _tabBody(label, match),
          ]),
        ),
      ]),
    );
  }

  Widget _tabBody(String label, FootballMatch match) {
    return switch (label) {
      'Resumen' => ListView(padding: const EdgeInsets.all(16), children: [
          if (match.isPrematch || match.isScheduled) ...[
            Text(match.kickoff == null
                ? 'Horario por confirmar'
                : 'Previa · ${_footballFormat('EEE d MMM · HH:mm').format(match.kickoff!)} (Lima)'),
            const SizedBox(height: 8),
            const Text('Las alineaciones y estadísticas aparecerán cerca del pitazo.'),
          ] else ...[
            Text(match.statusLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${match.home} ${match.homeScore ?? '–'} - ${match.awayScore ?? '–'} ${match.away}'),
          ],
        ]),
      'Eventos' => ListView(children: [
          Builder(builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadSection('EVENTS'); });
            return const SizedBox.shrink();
          }),
          _lazySection('EVENTS', builder: (items) => Column(children: [
            for (final item in items)
              ListTile(dense: true,
                leading: Icon(_eventIcon(item['type']?.toString())),
                title: Text(_eventTitle(item)),
                subtitle: Text([
                  if ((item['player']?.toString() ?? '').isNotEmpty)
                    footballEventLabel(item['type']?.toString(), detail: item['detail']?.toString()),
                  if ((item['team']?.toString() ?? '').isNotEmpty) item['team'].toString(),
                ].join(' · ')),
                trailing: Text(_minute(item))),
          ])),
        ]),
      'Alineaciones' => ListView(children: [
          Builder(builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadSection('LINEUPS'); });
            return const SizedBox.shrink();
          }),
          _lazySection('LINEUPS', builder: (items) => Column(children: [
            for (final item in items)
              ListTile(
                title: Text(item['team']?.toString() ?? 'Equipo'),
                subtitle: Text([
                  if ((item['formation']?.toString() ?? '').isNotEmpty) 'Esquema ${item['formation']}',
                  'Titulares: ${((item['starting'] as List?) ?? const []).join(' · ')}',
                ].join('\n'))),
          ])),
        ]),
      'Estadísticas' => ListView(children: [
          Builder(builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadSection('STATISTICS'); });
            return const SizedBox.shrink();
          }),
          _lazySection('STATISTICS', builder: (items) => Column(
            children: _statisticRows(items, match))),
        ]),
      'Tribuna' => ListView(padding: const EdgeInsets.all(12), children: [
          MatchTribunaSection(match: match),
        ]),
      _ => const SizedBox.shrink(),
    };
  }

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
