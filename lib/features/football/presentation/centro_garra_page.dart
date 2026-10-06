import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/connectivity_status.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/football_diagnostics.dart';
import '../data/garra_football_models.dart';
import '../data/garra_football_service.dart';
import 'football_event_timeline.dart';
import 'football_featured_hero.dart';
import 'football_lineup_view.dart';
import 'football_match_card.dart';
import 'football_standings_view.dart';
import 'football_team_center.dart';
import 'football_team_crest.dart';
import 'football_upcoming_rounds.dart';
import 'match_tribuna_section.dart';

final garraFootballServiceProvider = Provider<GarraFootballService>((ref) => GarraFootballService());

DateFormat _footballFormat(String pattern) {
  try {
    return DateFormat(pattern, 'es_PE');
  } on Exception {
    return DateFormat(pattern);
  }
}

/// SONIC_04 Navigation V4 — top level.
enum CentroHub { forYou, peru, international }

extension CentroHubLabel on CentroHub {
  String get label => switch (this) {
    CentroHub.forYou => 'Para ti',
    CentroHub.peru => 'Perú',
    CentroHub.international => 'Internacional',
  };
}

/// SONIC_04 Navigation V4 — second level.
enum CentroSection { today, live, upcoming, results, standings }

extension CentroSectionLabel on CentroSection {
  String get label => switch (this) {
    CentroSection.today => 'Hoy',
    CentroSection.live => 'En vivo',
    CentroSection.upcoming => 'Próximos',
    CentroSection.results => 'Resultados',
    CentroSection.standings => 'Tabla',
  };
  FootballView? get view => switch (this) {
    CentroSection.today => FootballView.today,
    CentroSection.live => FootballView.live,
    CentroSection.upcoming => FootballView.upcoming,
    CentroSection.results => FootballView.results,
    CentroSection.standings => null,
  };
}

/// Selection survives opening a match detail (and a rebuilt page).
@immutable
class CentroGarraNav {
  const CentroGarraNav({this.hub = CentroHub.forYou, this.section = CentroSection.today,
    this.competition, this.stage});
  final CentroHub hub;
  final CentroSection section;
  final String? competition;
  final String? stage;

  CentroGarraNav copyWith({CentroHub? hub, CentroSection? section, String? Function()? competition,
      String? Function()? stage}) => CentroGarraNav(
    hub: hub ?? this.hub,
    section: section ?? this.section,
    competition: competition == null ? this.competition : competition(),
    stage: stage == null ? this.stage : stage(),
  );
}

class CentroGarraNavController extends Notifier<CentroGarraNav> {
  @override
  CentroGarraNav build() => const CentroGarraNav();
  void set(CentroGarraNav value) => state = value;
}

final centroGarraNavProvider =
    NotifierProvider<CentroGarraNavController, CentroGarraNav>(CentroGarraNavController.new);

/// Short badge text from the competition name ("Liga 1 Perú" → "L1").
String competitionBadge(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(1, 3)).toUpperCase();
  final second = words[1];
  final tail = RegExp(r'^\d+$').hasMatch(second) ? second : second.substring(0, 1);
  return (words.first.substring(0, 1) + tail).toUpperCase();
}

class CentroGarraPage extends ConsumerStatefulWidget {
  const CentroGarraPage({super.key});

  @override
  ConsumerState<CentroGarraPage> createState() => _CentroGarraPageState();
}

class _CentroGarraPageState extends ConsumerState<CentroGarraPage>
    with AutomaticKeepAliveClientMixin {
  late CentroGarraNav _nav;
  List<FootballCompetition> _competitions = const [];
  final Map<String, FootballPage<FootballMatch>> _pages = {};
  final Map<String, FootballPage<Map<String, dynamic>>> _tables = {};
  FootballFeatured? _featured;
  bool _featuredLoaded = false;
  bool _loading = false;
  bool _failed = false;
  FootballFailureLayer? _failureLayer;
  final Set<String> _collapsed = {};
  final Set<String> _expanded = {};
  /// SONIC_05: round picked by the user per competition (PRÓXIMOS); survives detail / Team Center.
  final Map<String, String> _rounds = {};

  String get _pageKey => '${_nav.section.name}:${_nav.competition ?? 'ALL'}';

  @override
  bool get wantKeepAlive => true;

  bool get _nothingConfigured => _competitions.isNotEmpty &&
      !_competitions.any((competition) => competition.available);
  bool get _selectedUnconfigured => _nav.competition != null &&
      !_competitions.any((c) => c.id == _nav.competition && c.available);

  @override
  void initState() {
    super.initState();
    _nav = ref.read(centroGarraNavProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  void _setNav(CentroGarraNav nav) {
    setState(() => _nav = nav);
    ref.read(centroGarraNavProvider.notifier).set(nav);
  }

  List<FootballCompetition> _hubCompetitionsFor(CentroHub hub) {
    final available = _competitions.where((c) => c.available);
    return switch (hub) {
      CentroHub.peru => available.where((c) => c.isPeru).toList(),
      CentroHub.international => available.where((c) => c.isInternational).toList(),
      CentroHub.forYou => available.toList(),
    };
  }

  List<FootballCompetition> get _hubCompetitions => _hubCompetitionsFor(_nav.hub);

  String _competitionName(String id) =>
      _competitions.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? id;

  /// Competitions where the featured team plays (backend), else of featured rows, else Perú.
  Set<String> _featuredCompetitionIds(List<FootballMatch> items) {
    final fromBackend = _featured?.competitionIds ?? const [];
    if (fromBackend.isNotEmpty) return fromBackend.toSet();
    final fromRows = items.where((m) => m.featured).map((m) => m.competitionId).toSet();
    if (fromRows.isNotEmpty) return fromRows;
    return _competitions.where((c) => c.isPeru).map((c) => c.id).toSet();
  }

  /// PARA TI ≠ all competitions: featured, live, and the featured team's competitions.
  /// Perú / Internacional keep only their region (a "Todas" page is shared).
  List<FootballMatch> _visibleMatches(FootballPage<FootballMatch> page) {
    final items = page.items;
    switch (_nav.hub) {
      case CentroHub.forYou:
        final comps = _featuredCompetitionIds(items);
        return items.where((m) => m.featured || m.isLive || comps.contains(m.competitionId)).toList();
      case CentroHub.peru:
      case CentroHub.international:
        if (_nav.competition != null || _competitions.isEmpty) return items;
        final ids = _hubCompetitions.map((c) => c.id).toSet();
        return items.where((m) => ids.contains(m.competitionId)).toList();
    }
  }

  /// Hero: featured LIVE → next → last (backend), or the featured rows of today as fallback.
  ({FootballMatch match, String kind})? _hero(List<FootballMatch> today) {
    final f = _featured;
    if (f != null) {
      if (f.live != null) return (match: f.live!, kind: 'live');
      if (f.next != null) return (match: f.next!, kind: 'next');
      if (f.last != null) return (match: f.last!, kind: 'last');
      return null;
    }
    final featured = today.where((m) => m.featured).toList();
    final live = featured.where((m) => m.isLive).firstOrNull;
    if (live != null) return (match: live, kind: 'live');
    final next = featured.where((m) => m.isPrematch).firstOrNull;
    if (next != null) return (match: next, kind: 'next');
    final last = featured.where((m) => m.isFinished).lastOrNull;
    if (last != null) return (match: last, kind: 'last');
    return null;
  }

  void _chooseHub(CentroHub hub) {
    if (_nav.hub == hub) return;
    _setNav(_nav.copyWith(hub: hub, competition: () => null, stage: () => null));
    _load();
  }

  void _chooseSection(CentroSection section) {
    if (_nav.section == section) return;
    _setNav(_nav.copyWith(section: section, stage: () => null));
    _load();
  }

  void _chooseCompetition(String? id) {
    if (_nav.competition == id) return;
    _setNav(_nav.copyWith(competition: () => id, stage: () => null));
    _load();
  }

  String? _standingsCompetition() {
    if (_nav.competition != null) return _nav.competition;
    final available = _competitions.where((c) => c.available).map((c) => c.id).toSet();
    if (_nav.hub == CentroHub.forYou) {
      final featured = (_featured?.competitionIds ?? const <String>[]).where(available.contains).firstOrNull;
      if (featured != null) return featured;
      final peru = _competitions.where((c) => c.available && c.isPeru).map((c) => c.id).firstOrNull;
      if (peru != null) return peru;
    }
    return _hubCompetitions.map((c) => c.id).firstOrNull
        ?? _competitions.where((c) => c.available).map((c) => c.id).firstOrNull;
  }

  Future<void> _loadFeatured(GarraFootballService service, {bool refresh = false}) async {
    if (_featuredLoaded && !refresh) return;
    try {
      final featured = await service.featured();
      if (mounted) setState(() { _featured = featured; _featuredLoaded = true; });
    } catch (error) {
      // The hero falls back to today's featured rows; the list itself is not an outage.
      logFootballFailure('featured', error);
      if (mounted) setState(() => _featuredLoaded = true);
    }
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
    final key = _pageKey;
    try {
      final service = ref.read(garraFootballServiceProvider);
      if (_competitions.isEmpty || refresh) {
        _competitions = await service.competitions();
      }
      // Nothing configured: one compact notice, no futile provider-backed requests.
      if (_nothingConfigured) return;
      final featured = _nav.hub == CentroHub.forYou ? _loadFeatured(service, refresh: refresh) : null;
      final section = _nav.section;
      if (section != CentroSection.standings) {
        final view = section.view!;
        final page = await service.matches(view, competition: _nav.competition);
        logFootballAnswer('${view.wire}:${_nav.competition ?? 'ALL'}', page);
        if (mounted) setState(() => _pages[key] = page);
        await featured;
      } else {
        await featured;
        final id = _standingsCompetition();
        if (id != null) {
          final table = await service.standings(id);
          logFootballAnswer('standings:$id', table);
          if (mounted) setState(() => _tables[id] = table);
        }
      }
    } catch (error) {
      logFootballFailure(key, error);
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

  bool get _hasCurrentContent => _nav.section == CentroSection.standings
      ? _tables.containsKey(_standingsCompetition())
      : _pages.containsKey(_pageKey);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final offline = ref.watch(connectivityStatusProvider) == NetworkConnectivity.offline;
    final page = _pages[_pageKey];
    final standingsId = _nav.section == CentroSection.standings ? _standingsCompetition() : null;
    final table = standingsId == null ? null : _tables[standingsId];
    final showFilter = _nav.hub != CentroHub.forYou && _hubCompetitions.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro Garra'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              key: const ValueKey('chat_futbolero_entry'),
              icon: const Icon(Icons.forum_outlined, size: 20),
              label: const Text('Chat Futbolero'),
              onPressed: () => context.push('/centro-garra/chat-futbolero'),
            ),
          ),
        ],
      ),
      body: Column(children: [
        _HubTabs(selected: _nav.hub, onSelected: _chooseHub),
        _SectionTabs(selected: _nav.section, onSelected: _chooseSection),
        if (showFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('competition_filter'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact,
                    shape: const StadiumBorder()),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text(_nav.competition != null
                    ? _competitionName(_nav.competition!)
                    : _nav.section == CentroSection.standings && standingsId != null
                        ? _competitionName(standingsId)
                        : 'Todas las competiciones'),
                onPressed: _pickCompetition,
              ),
            ),
          ),
        if (_loading && !_hasCurrentContent) const LinearProgressIndicator(),
        Expanded(child: _body(page, table, standingsId, offline)),
      ]),
    );
  }

  Future<void> _pickCompetition() async {
    final standings = _nav.section == CentroSection.standings;
    const all = '__all__';
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          if (!standings)
            ListTile(
              key: const ValueKey('competition_option_ALL'),
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('Todas las competiciones'),
              trailing: _nav.competition == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(all),
            ),
          for (final c in _hubCompetitions)
            ListTile(
              key: ValueKey('competition_option_${c.id}'),
              leading: _CompetitionBadge(name: c.name),
              title: Text(c.name),
              trailing: _nav.competition == c.id ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(c.id),
            ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    _chooseCompetition(picked == all ? null : picked);
  }

  Widget _body(FootballPage<FootballMatch>? page,
      FootballPage<Map<String, dynamic>>? table, String? standingsId, bool offline) {
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
    if (_nav.section == CentroSection.standings) {
      return _standingsBody(table, standingsId, offline);
    }
    final unconfigured = _nothingConfigured || _selectedUnconfigured;
    if (page == null && !unconfigured) return const GarraHomeSkeleton();
    // SONIC_04: total outage only when nothing answered; a partial answer is a soft note.
    if (page == null || (page.items.isEmpty && page.unavailable) || unconfigured) {
      return _notice(
        unconfigured ? 'Competiciones por activar' : 'Fútbol temporalmente no disponible',
        offline ? 'Conéctate para consultar nuevos partidos.'
            : unconfigured ? 'Los partidos aparecerán cuando las competiciones estén disponibles.'
            : 'No pudimos traer los partidos. Inténtalo más tarde.',
        retry: !offline && !unconfigured);
    }
    final items = _visibleMatches(page);
    final notes = <Widget>[
      if (page.partial) _compactBanner('Algunas competiciones no están disponibles',
          key: const ValueKey('partial_notice')),
      if (page.stale) _softNote('Datos guardados · pueden estar desactualizados',
          key: const ValueKey('stale_notice')),
    ];
    // SONIC_05: PRÓXIMOS of one competition = round selector with complete rounds.
    final competition = _nav.competition;
    if (_nav.section == CentroSection.upcoming && competition != null && items.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: FootballUpcomingRounds(
          key: ValueKey('rounds_$competition'),
          competitionName: _competitionName(competition),
          matches: items,
          selectedRound: _rounds[competition],
          featuredNextId: _featured?.next?.id,
          onRoundChanged: (round) => setState(() => _rounds[competition] = round),
          onOpen: _openMatch,
          onTeamTap: _openTeam,
          header: notes,
        ),
      );
    }
    final hero = _nav.hub == CentroHub.forYou && _nav.section == CentroSection.today
        ? _hero(page.items) : null;
    final others = items.where((m) => m.id != hero?.match.id).toList();
    final children = <Widget>[
      ...notes,
      if (hero != null)
        FootballFeaturedHero(
          match: hero.match, kind: hero.kind, name: _featured?.displayName,
          featuredTeamId: _featured?.teamId,
          secondary: [
            if (_featured != null && hero.kind == 'live' && _featured!.next != null)
              ('Próximo', _featured!.next!),
            if (_featured != null && hero.kind != 'last' && _featured!.last != null)
              ('Último', _featured!.last!),
          ],
          onOpen: _openMatch,
          onTeamTap: _openTeam,
        ),
    ];
    if (others.isEmpty) {
      if (hero == null) {
        final (emptyTitle, emptyMessage) = _nav.hub == CentroHub.forYou && page.items.isNotEmpty
            ? ('Nada destacado por ahora', 'Cuando tu equipo juegue o haya partidos en vivo, aparecerán aquí.')
            : switch (_nav.section) {
                CentroSection.live => ('Ningún partido en vivo ahora', 'Cuando empiece un partido lo verás aquí.'),
                CentroSection.upcoming => ('Sin partidos próximos', _nav.competition == null
                    ? 'No hay partidos en los próximos 7 días.'
                    : 'Esta competición no tiene fechas por jugar en el calendario guardado.'),
                CentroSection.results => ('Sin resultados recientes', 'No hay resultados de los últimos 7 días.'),
                _ => ('Sin partidos hoy', 'No hay partidos programados para hoy en estas competiciones.'),
              };
        children.add(_emptyCard(emptyTitle, emptyMessage));
      }
    } else {
      if (hero != null) {
        children.add(Padding(
          key: const ValueKey('others_header'),
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 2),
          child: Text('OTROS PARTIDOS', style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        ));
      }
      children.addAll(_groups(others));
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: children,
      ),
    );
  }

  void _openMatch(FootballMatch match) => context.push(
      '/centro-garra/partido/${match.id}?competition=${match.competitionId}', extra: match);

  /// SONIC_05: Team Center for any provider team id (sheet over the current tab; selection kept).
  void _openTeam(int teamId, String name, String? crestUrl) => showFootballTeamCenter(context,
      teamId: teamId, name: name, crestUrl: crestUrl,
      load: () => ref.read(garraFootballServiceProvider).team(teamId),
      onOpenMatch: _openMatch);

  /// Competition groups: featured first, then groups with live matches, then catalog order.
  List<Widget> _groups(List<FootballMatch> items) {
    final order = <String>[];
    final byComp = <String, List<FootballMatch>>{};
    for (final m in items) {
      byComp.putIfAbsent(m.competitionId, () { order.add(m.competitionId); return []; }).add(m);
    }
    int catalogIndex(String id) {
      final i = _competitions.indexWhere((c) => c.id == id);
      return i < 0 ? 1 << 20 : i;
    }
    final featuredComps = _featuredCompetitionIds(items);
    int rank(String id) {
      final list = byComp[id]!;
      if (list.any((m) => m.featured)) return 0;
      if (featuredComps.contains(id)) return 1;
      if (list.any((m) => m.isLive)) return 2;
      return 3;
    }
    order.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : catalogIndex(a).compareTo(catalogIndex(b));
    });
    return [
      for (final id in order)
        _CompetitionGroup(
          key: ValueKey('comp_group_$id'),
          competitionId: id,
          name: byComp[id]!.first.competition.isEmpty ? _competitionName(id) : byComp[id]!.first.competition,
          matches: _sortWithinGroup(byComp[id]!),
          collapsed: _collapsed.contains('${_nav.section.name}:$id'),
          expanded: _expanded.contains('${_nav.section.name}:$id'),
          onToggle: () => setState(() {
            final k = '${_nav.section.name}:$id';
            if (!_collapsed.remove(k)) _collapsed.add(k);
          }),
          onShowAll: () => setState(() => _expanded.add('${_nav.section.name}:$id')),
          onOpen: _openMatch,
          onTeamTap: _openTeam,
        ),
    ];
  }

  List<FootballMatch> _sortWithinGroup(List<FootballMatch> list) {
    final sorted = [...list];
    final results = _nav.section == CentroSection.results;
    sorted.sort((a, b) {
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      final ak = a.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bk = b.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
      return results ? bk.compareTo(ak) : ak.compareTo(bk);
    });
    return sorted;
  }

  Widget _standingsBody(FootballPage<Map<String, dynamic>>? table, String? id, bool offline) {
    final unconfigured = _nothingConfigured || _selectedUnconfigured || id == null;
    if (id == null || table == null || table.items.isEmpty) {
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
    final stage = stages.any((s) => s.name == _nav.stage) ? _nav.stage : stages.first.name;
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: FootballStandingsView(
        rows: table.items,
        competitionName: _competitionName(id),
        selectedStage: stage,
        featuredTeamId: _featured?.teamId,
        onStageChanged: (name) => _setNav(_nav.copyWith(stage: () => name)),
        onTeamTap: _openTeam,
        footer: table.stale
            ? _softNote('Datos guardados · pueden estar desactualizados')
            : null,
      ),
    );
  }

  Widget _softNote(String message, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(children: [
      Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 6),
      Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
    ]),
  );

  /// SONIC_10: partial availability = one compact, non-invasive line (not a card, not a block).
  Widget _compactBanner(String message, {Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      key: key,
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.info_outline, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(child: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))),
        ]),
      ),
    );
  }

  Widget _emptyCard(String title, String message) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ]))),
  );

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

/// Para ti | Perú | Internacional — three equal tabs, no chip noise.
class _HubTabs extends StatelessWidget {
  const _HubTabs({required this.selected, required this.onSelected});
  final CentroHub selected;
  final ValueChanged<CentroHub> onSelected;

  @override
  Widget build(BuildContext context) {
    final garra = garraColors(context);
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)))),
      child: Row(children: [
        for (final hub in CentroHub.values)
          Expanded(
            child: InkWell(
              key: ValueKey('hub_${hub.name}'),
              onTap: () => onSelected(hub),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(
                    width: 3, color: hub == selected ? garra.brandPrimary : Colors.transparent))),
                child: Text(hub.label, style: text.titleSmall?.copyWith(
                    fontWeight: hub == selected ? FontWeight.w900 : FontWeight.w600,
                    color: hub == selected ? null : Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Hoy · En vivo · Próximos · Resultados · Tabla — text tabs like a sports app.
/// SONIC_05: the active tab is always fully visible (on entry, on change and after coming back
/// from a detail / Team Center): no "Hoy" cut at the edge.
class _SectionTabs extends StatefulWidget {
  const _SectionTabs({required this.selected, required this.onSelected});
  final CentroSection selected;
  final ValueChanged<CentroSection> onSelected;

  @override
  State<_SectionTabs> createState() => _SectionTabsState();
}

class _SectionTabsState extends State<_SectionTabs> {
  final ScrollController _scroll = ScrollController();
  final Map<CentroSection, GlobalKey> _keys = {for (final s in CentroSection.values) s: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(covariant _SectionTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal(animate: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[widget.selected]?.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(ctx, alignment: 0.5,
          duration: animate ? const Duration(milliseconds: 220) : Duration.zero, curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final garra = garraColors(context);
    final text = Theme.of(context).textTheme;
    final selected = widget.selected;
    // Five fixed tabs: a non-lazy Row keeps every tab built (a11y + tests) and still scrolls.
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        key: const ValueKey('section_tabs_scroll'),
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(children: [
          for (final section in CentroSection.values)
            InkWell(
              key: ValueKey('section_${section.name}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onSelected(section),
              child: Padding(
                key: _keys[section],
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (section == CentroSection.live)
                      Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(color: garra.danger, shape: BoxShape.circle)),
                    Text(section.label, maxLines: 1, softWrap: false, style: text.labelLarge?.copyWith(
                        fontWeight: section == selected ? FontWeight.w900 : FontWeight.w500,
                        color: section == selected ? null
                            : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 4),
                  Container(height: 2, width: 22,
                      color: section == selected ? garra.brandPrestige : Colors.transparent),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _CompetitionBadge extends StatelessWidget {
  const _CompetitionBadge({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28, height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant)),
      child: Text(competitionBadge(name), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

/// Collapsible competition section: about 3 matches, then "Ver todos".
class _CompetitionGroup extends StatelessWidget {
  const _CompetitionGroup({super.key, required this.competitionId, required this.name,
    required this.matches, required this.collapsed, required this.expanded,
    required this.onToggle, required this.onShowAll, required this.onOpen, this.onTeamTap});
  static const initialCount = 3;
  final String competitionId;
  final String name;
  final List<FootballMatch> matches;
  final bool collapsed;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onShowAll;
  final ValueChanged<FootballMatch> onOpen;
  final FootballTeamTap? onTeamTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final garra = garraColors(context);
    final live = matches.where((m) => m.isLive).length;
    final visible = expanded ? matches : matches.take(initialCount).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        key: ValueKey('comp_toggle_$competitionId'),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
          child: Row(children: [
            _CompetitionBadge(name: name),
            const SizedBox(width: 10),
            Expanded(child: Text(name, key: ValueKey('comp_header_$name'), maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
            if (live > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: garra.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('$live EN VIVO', style: TextStyle(color: garra.danger, fontSize: 10,
                    fontWeight: FontWeight.w900)),
              ),
            Text('${matches.length}', style: text.labelMedium),
            Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 20),
          ]),
        ),
      ),
      if (!collapsed) ...[
        for (final m in visible)
          FootballMatchCard(key: ValueKey('match_${m.id}'), match: m, showCompetitionHeader: false,
              onTap: () => onOpen(m), onTeamTap: onTeamTap),
        if (!expanded && matches.length > initialCount)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                key: ValueKey('ver_todos_$competitionId'),
                onPressed: onShowAll,
                child: Text('Ver todos (${matches.length})'),
              ),
            ),
          ),
      ],
    ]);
  }
}

class CentroGarraMatchDetailPage extends ConsumerStatefulWidget {
  const CentroGarraMatchDetailPage({super.key, required this.match});
  final FootballMatch match;
  @override
  ConsumerState<CentroGarraMatchDetailPage> createState() => _CentroGarraMatchDetailPageState();
}

class _CentroGarraMatchDetailPageState extends ConsumerState<CentroGarraMatchDetailPage>
    with TickerProviderStateMixin {
  static const _sectionOfLabel = {'Eventos': 'EVENTS', 'Alineación': 'LINEUPS', 'Stats': 'STATISTICS'};
  FootballDetail? _detail;
  late FootballMatch _match;
  bool _loading = true;
  bool _failed = false;
  final Map<String, List<Map<String, dynamic>>> _sections = {};
  final Set<String> _sectionLoading = {};
  final Set<String> _sectionFailed = {};
  late List<String> _labels;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _labels = _computeLabels(keep: null);
    _tabs = _controller(0);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  TabController _controller(int index) {
    final controller = TabController(length: _labels.length, vsync: this, initialIndex: index);
    controller.addListener(() {
      if (controller.indexIsChanging || controller != _tabs) return;
      _ensureTabLoaded(controller.index);
      // Tabs whose section came back empty disappear once the user leaves them.
      if (mounted) setState(_syncTabs);
    });
    return controller;
  }

  /// SONIC_04: tabs from status; data tabs known to be empty are hidden (except the open one).
  List<String> _computeLabels({required String? keep}) {
    final m = _match;
    bool show(String label) {
      final section = _sectionOfLabel[label]!;
      final items = _sections[section];
      return label == keep || items == null || items.isNotEmpty;
    }
    if (m.status == 'POSTPONED' || m.status == 'CANCELLED') return const ['Resumen', 'Tribuna'];
    if (m.isPrematch) return ['Resumen', if (show('Alineación')) 'Alineación', 'Tribuna'];
    return ['Resumen', if (show('Eventos')) 'Eventos', if (show('Alineación')) 'Alineación',
      if (show('Stats')) 'Stats', 'Tribuna'];
  }

  /// Never called from build: only from initState / setState callbacks.
  void _syncTabs() {
    final current = _labels[_tabs.index.clamp(0, _labels.length - 1)];
    final next = _computeLabels(keep: current);
    if (listEquals(next, _labels)) return;
    final old = _tabs;
    _labels = next;
    final index = next.indexOf(current);
    _tabs = _controller(index < 0 ? 0 : index);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _adopt(FootballMatch incoming) => _match = FootballMatch.fresher(_match, incoming);

  Future<void> _load() async {
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      setState(() { _loading = false; _failed = _detail == null; }); return;
    }
    setState(() { _loading = true; _failed = false; });
    try {
      final result = await ref.read(garraFootballServiceProvider).detail(_match);
      if (mounted) {
        setState(() {
          _detail = result;
          _failed = result == null;
          if (result != null) _adopt(result.match);
          _syncTabs();
        });
      }
    } catch (error) {
      logFootballFailure('detail', error);
      if (mounted) setState(() => _failed = true);
    }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _ensureTabLoaded(int index) {
    if (index < 0 || index >= _labels.length) return;
    final section = _sectionOfLabel[_labels[index]];
    if (section != null) _loadSection(section);
  }

  Future<void> _loadSection(String section) async {
    if (_detail == null || _sections.containsKey(section) || _sectionLoading.contains(section)) return;
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      setState(() => _sectionFailed.add(section));
      return;
    }
    setState(() { _sectionLoading.add(section); _sectionFailed.remove(section); });
    try {
      final result = await ref.read(garraFootballServiceProvider).detail(_match, section: section);
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
          // The section answer carries the freshest header the backend has (events reconcile it).
          _adopt(result.match);
        }
      });
    } catch (error) {
      logFootballFailure('detail:$section', error);
      if (mounted) setState(() => _sectionFailed.add(section));
    } finally {
      if (mounted) setState(() => _sectionLoading.remove(section));
    }
  }

  /// Header shown: events are provider facts; a live minute behind them is withheld.
  FootballMatch get _display {
    final m = _match;
    final events = _sections['EVENTS'];
    if (events == null || !m.isLive || m.isUnconfirmed || m.elapsed == null) return m;
    final latest = latestEventMinute(events);
    if (latest == null) return m;
    final behind = latest.$1 > m.elapsed! || (latest.$1 == m.elapsed! && latest.$2 > (m.elapsedExtra ?? 0));
    return behind ? m.degraded() : m;
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
    final match = _display;
    return Scaffold(
      appBar: AppBar(title: Text(match.competition.isEmpty ? 'Partido' : match.competition)),
      body: Column(children: [
        _DetailHeader(match: match, stateLine: _stateLine(match), onTeamTap: _openTeam),
        if (match.isLive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey('talk_match_cta'),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Hablar del partido'),
                onPressed: () => context.push(
                    '/centro-garra/chat-futbolero?tema=${Uri.encodeComponent('${match.home} vs ${match.away}')}'),
              ),
            ),
          ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_failed) ListTile(dense: true, title: const Text('No pudimos actualizar este partido'),
          trailing: TextButton(onPressed: _load, child: const Text('Reintentar'))),
        if (detail?.stale == true || detail?.partial == true) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Text(detail!.stale
            ? 'Datos guardados · pueden estar desactualizados'
            : 'Algunos datos del partido aún no están disponibles',
            style: Theme.of(context).textTheme.bodySmall)),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          onTap: _ensureTabLoaded,
          tabs: [for (final label in _labels) Tab(text: label)],
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            for (final label in _labels) _tabBody(label, match),
          ]),
        ),
      ]),
    );
  }

  void _openTeam(int teamId, String name, String? crestUrl) => showFootballTeamCenter(context,
      teamId: teamId, name: name, crestUrl: crestUrl,
      load: () => ref.read(garraFootballServiceProvider).team(teamId),
      onOpenMatch: (m) => context.push('/centro-garra/partido/${m.id}?competition=${m.competitionId}', extra: m));

  /// SONIC_05 Resumen row: icon, small label, full value (wraps, never truncated).
  Widget _infoRow(IconData icon, String label, String value, {required String key}) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: garraColors(context).brandPrestige),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: text.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w800,
              letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(value, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _autoLoad(String section) => Builder(builder: (context) {
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadSection(section); });
    return const SizedBox.shrink();
  });

  Widget _tabBody(String label, FootballMatch match) {
    final text = Theme.of(context).textTheme;
    return switch (label) {
      // SONIC_05 Resumen V5: stadium, date / time, competition / round, state; refresh time discreet.
      'Resumen' => ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          _infoRow(Icons.emoji_events_outlined, 'Competición', [
            if (match.competition.isNotEmpty) match.competition,
            ?match.roundLabel,
          ].join(' · ').ifEmpty('Por confirmar'), key: 'resumen_competition'),
          _infoRow(Icons.event_rounded, 'Fecha y hora', footballKickoffLine(match), key: 'resumen_kickoff'),
          _infoRow(Icons.stadium_outlined, 'Estadio', match.venue ?? 'Por confirmar', key: 'resumen_venue'),
          _infoRow(Icons.flag_outlined, 'Estado', _statusWord(match), key: 'resumen_state'),
          if (match.isPrematch)
            Text('Las alineaciones aparecerán cerca del pitazo.', style: text.bodySmall),
          if (match.snapshotAt != null) ...[
            const SizedBox(height: 16),
            Text('Actualizado ${_footballFormat('HH:mm').format(limaWallClock(match.snapshotAt!))} (hora de Lima)',
                key: const ValueKey('snapshot_line'),
                style: text.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      'Eventos' => ListView(padding: const EdgeInsets.only(top: 8, bottom: 16), children: [
          _autoLoad('EVENTS'),
          _lazySection('EVENTS', builder: (items) => FootballEventTimeline(events: items, match: match)),
        ]),
      'Alineación' => ListView(children: [
          _autoLoad('LINEUPS'),
          _lazySection('LINEUPS', builder: (items) => Column(children: [
            for (var i = 0; i < items.length; i++)
              FootballLineupCard(
                key: ValueKey('lineup_card_$i'),
                lineup: FootballLineup.fromJson(items[i]),
                fallbackCrest: items[i]['team']?.toString() == match.home ? match.homeCrestUrl
                    : items[i]['team']?.toString() == match.away ? match.awayCrestUrl : null,
              ),
            const SizedBox(height: 16),
          ])),
        ]),
      'Stats' => ListView(padding: const EdgeInsets.only(top: 8), children: [
          _autoLoad('STATISTICS'),
          _lazySection('STATISTICS', builder: (items) => Column(
            children: _statisticRows(items, match))),
        ]),
      'Tribuna' => ListView(padding: const EdgeInsets.all(12), children: [
          MatchTribunaSection(match: match),
        ]),
      _ => const SizedBox.shrink(),
    };
  }

  /// Short Resumen state (the header keeps the full state line; no duplicated sentence).
  String _statusWord(FootballMatch match) {
    if (match.isUnconfirmed) return match.isLive ? 'En juego · actualizando' : 'Por confirmar';
    if (match.isLive) return 'En juego';
    return switch (match.status) {
      'FINISHED' => 'Finalizado',
      'POSTPONED' => 'Postergado',
      'CANCELLED' => 'Cancelado',
      'SCHEDULED' => match.kickoffConfirmed == false ? 'Por jugar · hora por confirmar' : 'Por jugar',
      _ => 'Por confirmar',
    };
  }

  String _stateLine(FootballMatch match) {
    final kickoff = match.kickoff;
    if (match.isUnconfirmed) {
      return match.isLive ? 'En juego · datos en actualización' : 'Estado por confirmar · datos en actualización';
    }
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
    double? number(String? v) => v == null ? null : double.tryParse(v.replaceAll('%', '').trim());
    final garra = garraColors(context);
    return [
      for (final entry in rows.entries)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Column(children: [
            Row(children: [
              SizedBox(width: 56, child: Text(entry.value[0] ?? '–',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(child: Text(footballStatLabel(entry.key), textAlign: TextAlign.center)),
              SizedBox(width: 56, child: Text(entry.value[1] ?? '–', textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
            Builder(builder: (context) {
              final a = number(entry.value[0]);
              final b = number(entry.value[1]);
              if (a == null || b == null || a + b <= 0) return const SizedBox(height: 4);
              final share = a / (a + b);
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(children: [
                    Expanded(flex: (share * 1000).round().clamp(1, 999),
                        child: Container(height: 5, color: garra.brandPrimary)),
                    Expanded(flex: ((1 - share) * 1000).round().clamp(1, 999),
                        child: Container(height: 5, color: garra.brandPrestige)),
                  ]),
                ),
              );
            }),
          ]),
        ),
    ];
  }
}

/// SONIC_04 Detail V4 compact header: competition line, teams, score/time, state line.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.match, required this.stateLine, this.onTeamTap});
  final FootballMatch match;
  final String stateLine;
  final FootballTeamTap? onTeamTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final garra = garraColors(context);
    final live = match.isLive && !match.isUnconfirmed;
    final showScore = match.isLive || match.isFinished || match.homeScore != null;
    final competitionLine = [
      if (match.competition.isNotEmpty) match.competition,
      ?match.roundLabel,
    ].join(' · ');
    Widget team(String name, String? crest, int? id, String side) {
      final body = Column(children: [
        FootballTeamCrest(name: name, url: crest, size: 40),
        const SizedBox(height: 6),
        Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
      ]);
      return Expanded(
        child: id == null || onTeamTap == null ? body : InkWell(
          key: ValueKey('detail_team_$side'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTeamTap!(id, name, crest),
          child: body,
        ),
      );
    }
    final scoreStyle = text.headlineMedium?.copyWith(fontWeight: FontWeight.w900,
        color: live ? garra.danger : null);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: match.featured
            ? garra.brandPrimary.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: match.featured ? Border.all(color: garra.brandPrestige.withValues(alpha: 0.8)) : null,
      ),
      child: Column(children: [
        if (competitionLine.isNotEmpty)
          Text(competitionLine, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          team(match.home, match.homeCrestUrl, match.homeId, 'home'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: showScore
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${match.homeScore ?? '–'}', key: const ValueKey('detail_score_home'), style: scoreStyle),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('-', style: scoreStyle)),
                    Text('${match.awayScore ?? '–'}', key: const ValueKey('detail_score_away'), style: scoreStyle),
                  ])
                : Column(children: [
                    Text(match.kickoff == null ? '–' : _footballFormat('HH:mm').format(match.kickoff!),
                        style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    if (match.kickoff != null)
                      Text(footballDayLabel(match.kickoff!), style: text.labelSmall),
                  ]),
          ),
          team(match.away, match.awayCrestUrl, match.awayId, 'away'),
        ]),
        const SizedBox(height: 8),
        Text(stateLine, key: const ValueKey('match_state_line'), textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800,
                color: match.isUnconfirmed ? garra.warning : live ? garra.danger : null)),
        if (match.isUnconfirmed)
          Padding(
            key: const ValueKey('match_unconfirmed_note'),
            padding: const EdgeInsets.only(top: 4),
            child: Text('Minuto no disponible hasta confirmar con el proveedor.',
                textAlign: TextAlign.center, style: text.bodySmall),
          ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
