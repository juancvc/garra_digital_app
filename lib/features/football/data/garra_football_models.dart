enum FootballView { today, live, upcoming, results }

/// SONIC_01: Centro Garra shows every time in America/Lima. Peru has no DST
/// (UTC-5 all year), so the wall clock is derived without a tz database and
/// is independent of the device time zone.
const limaUtcOffset = Duration(hours: -5);

DateTime limaWallClock(DateTime instant) {
  final lima = instant.toUtc().add(limaUtcOffset);
  return DateTime(lima.year, lima.month, lima.day, lima.hour, lima.minute,
      lima.second);
}

extension FootballViewWire on FootballView {
  String get wire => name.toUpperCase();
  String get label => switch (this) {
    FootballView.today => 'Hoy',
    FootballView.live => 'En vivo',
    FootballView.upcoming => 'Próximos',
    FootballView.results => 'Resultados',
  };
}

class FootballCompetition {
  const FootballCompetition({required this.id, required this.name, required this.available,
    this.region = 'OTHER', this.group = 'other'});
  final String id;
  final String name;
  final bool available;
  final String region;
  final String group;
  bool get isPeru => region == 'PERU';
  bool get isInternational => !isPeru;
  factory FootballCompetition.fromJson(Map<String, dynamic> json) => FootballCompetition(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    available: json['available'] == true,
    region: json['region']?.toString() ?? 'OTHER',
    group: json['group']?.toString() ?? 'other',
  );
}

class FootballMatch {
  const FootballMatch({required this.id, required this.competitionId,
    required this.competition, required this.home, required this.away,
    required this.status, this.kickoff, this.elapsed, this.elapsedExtra,
    this.homeScore, this.awayScore, this.garraMatchId, this.round,
    this.homeId, this.awayId, this.homeCrestUrl, this.awayCrestUrl,
    this.featured = false, this.snapshotAt, this.dataState, this.venue, this.kickoffConfirmed});
  final int id;
  final String competitionId;
  final String competition;
  final String home;
  final String away;
  final String status;
  final DateTime? kickoff;
  final int? elapsed;
  /// Provider status.extra (injury time). Never invent a local chronometer.
  final int? elapsedExtra;
  final int? homeScore;
  final int? awayScore;
  final String? garraMatchId;
  final String? round;
  final int? homeId;
  final int? awayId;
  final String? homeCrestUrl;
  final String? awayCrestUrl;
  final bool featured;
  /// SONIC_04: when the provider snapshot behind status/score/minute was taken (UTC).
  final DateTime? snapshotAt;
  /// SONIC_04: LIVE_SNAPSHOT / SEASON_SNAPSHOT / UNCONFIRMED (backend single temporal truth).
  final String? dataState;
  /// SONIC_05: provider stadium name (null when absent).
  final String? venue;
  /// SONIC_05: false when the provider marks the time TBD / postponed (date is a placeholder).
  final bool? kickoffConfirmed;

  /// Date shown is a provider placeholder (time to be defined or postponed).
  bool get isKickoffTentative => kickoffConfirmed == false || kickoff == null;

  /// In play or past kickoff, but no fresh snapshot confirms it: never show a minute.
  bool get isUnconfirmed => dataState == 'UNCONFIRMED';

  /// SONIC_04: one temporal truth. The newer provider snapshot wins; without
  /// timestamps the latest backend answer wins (as before).
  static FootballMatch fresher(FootballMatch current, FootballMatch incoming) {
    final a = current.snapshotAt;
    final b = incoming.snapshotAt;
    if (a != null && b != null && b.isBefore(a)) return current;
    return incoming;
  }

  /// Same match with the minute withheld (data in update), never a local clock.
  FootballMatch degraded() => FootballMatch(id: id, competitionId: competitionId,
      competition: competition, home: home, away: away, status: status, kickoff: kickoff,
      homeScore: homeScore, awayScore: awayScore, garraMatchId: garraMatchId, round: round,
      homeId: homeId, awayId: awayId, homeCrestUrl: homeCrestUrl, awayCrestUrl: awayCrestUrl,
      featured: featured, snapshotAt: snapshotAt, dataState: 'UNCONFIRMED', venue: venue,
      kickoffConfirmed: kickoffConfirmed);

  factory FootballMatch.fromJson(Map<String, dynamic> json) {
    final home = json['home'] as Map?;
    final away = json['away'] as Map?;
    return FootballMatch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      competitionId: json['competitionId']?.toString() ?? '',
      competition: json['competition']?.toString() ?? '',
      home: home?['name']?.toString() ?? 'Por confirmar',
      away: away?['name']?.toString() ?? 'Por confirmar',
      homeId: (home?['id'] as num?)?.toInt(),
      awayId: (away?['id'] as num?)?.toInt(),
      homeCrestUrl: _crest(home?['crestUrl'] ?? home?['logoUrl']),
      awayCrestUrl: _crest(away?['crestUrl'] ?? away?['logoUrl']),
      status: json['status']?.toString() ?? 'UNKNOWN',
      kickoff: _limaKickoff(json['kickoff']),
      elapsed: (json['elapsed'] as num?)?.toInt(),
      elapsedExtra: (json['elapsedExtra'] as num?)?.toInt(),
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
      garraMatchId: json['garraMatchId']?.toString(),
      round: json['round']?.toString(),
      featured: json['featured'] == true,
      snapshotAt: DateTime.tryParse(json['snapshotAt']?.toString() ?? '')?.toUtc(),
      dataState: json['dataState']?.toString(),
      venue: _text(json['venue']),
      kickoffConfirmed: json['kickoffConfirmed'] is bool ? json['kickoffConfirmed'] as bool : null,
    );
  }

  /// Not played and not cancelled as far as the provider knows (incl. postponed / time TBD).
  bool get isPending => isPrematch || status == 'POSTPONED';

  /// Provider team id of the side that is [teamId], or null.
  bool? isHomeOf(int? teamId) {
    if (teamId == null) return null;
    if (homeId == teamId) return true;
    if (awayId == teamId) return false;
    return null;
  }

  bool get isLive => const {
    'LIVE', 'FIRST_HALF', 'HALFTIME', 'SECOND_HALF', 'EXTRA_TIME', 'PENALTIES', 'SUSPENDED',
  }.contains(status);
  bool get isFinished => status == 'FINISHED';
  bool get isScheduled => status == 'SCHEDULED';
  bool get isPrematch => isScheduled || status == 'UNKNOWN';

  String? get roundLabel {
    final raw = round?.trim() ?? '';
    if (raw.isEmpty) return null;
    final regular = RegExp(r'^Regular Season\s*-\s*(\d+)$', caseSensitive: false)
        .firstMatch(raw);
    if (regular != null) return 'Fecha ${regular.group(1)}';
    final phase = RegExp(r'^(.+?)\s*-\s*(\d+)$').firstMatch(raw);
    if (phase != null) return '${phase.group(1)} · Fecha ${phase.group(2)}';
    return raw;
  }

  /// Minute from provider only: 67' or 45+2'. Empty when no elapsed.
  String? get liveMinuteLabel {
    if (isUnconfirmed) return null;
    final e = elapsed;
    if (e == null) return null;
    final x = elapsedExtra;
    if (x != null && x > 0) return "$e+$x′";
    return "$e′";
  }

  /// SONIC_03: EN VIVO · 67' / DESCANSO / 1.º TIEMPO — never a local clock.
  String get statusLabel {
    final minute = liveMinuteLabel;
    if (isUnconfirmed) return isLive ? 'EN JUEGO · ACTUALIZANDO' : 'POR CONFIRMAR';
    return switch (status) {
      'LIVE' => minute == null ? 'EN VIVO' : 'EN VIVO · $minute',
      'FIRST_HALF' => minute == null ? '1.º TIEMPO' : 'EN VIVO · $minute',
      'HALFTIME' => 'DESCANSO',
      'SECOND_HALF' => minute == null ? '2.º TIEMPO' : 'EN VIVO · $minute',
      'EXTRA_TIME' => minute == null ? 'PRÓRROGA' : 'EN VIVO · $minute',
      'PENALTIES' => 'PENALES',
      'SUSPENDED' => 'SUSPENDIDO',
      'FINISHED' => 'FINALIZADO',
      'POSTPONED' => 'POSTERGADO',
      'CANCELLED' => 'CANCELADO',
      'SCHEDULED' => 'PROGRAMADO',
      _ => 'ESTADO POR CONFIRMAR',
    };
  }
}

String? _text(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

/// SONIC_05: shared crest validation (cards, standings, lineups, Team Center): http(s) only.
String? footballCrestUrl(Object? raw) => _crest(raw);

const _limaWeekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _limaMonths = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
  'septiembre', 'octubre', 'noviembre', 'diciembre'];

/// SONIC_05: full Spanish date for a Lima wall-clock kickoff: "domingo 18 de octubre".
/// Locale-data independent (no intl initialization needed), never truncated.
String footballFullDate(DateTime limaKickoff) =>
    '${_limaWeekdays[limaKickoff.weekday - 1]} ${limaKickoff.day} de ${_limaMonths[limaKickoff.month - 1]}';

/// "15:30" for a Lima wall-clock kickoff.
String footballClock(DateTime limaKickoff) =>
    '${limaKickoff.hour.toString().padLeft(2, '0')}:${limaKickoff.minute.toString().padLeft(2, '0')}';

/// SONIC_05: "domingo 18 de octubre · 15:30 (hora de Lima)", or an honest tentative text.
String footballKickoffLine(FootballMatch m) {
  final k = m.kickoff;
  if (m.status == 'POSTPONED') {
    return k == null ? 'Partido postergado · nueva fecha por confirmar'
        : 'Partido postergado · programado para el ${footballFullDate(k)} · nueva fecha por confirmar';
  }
  if (k == null) return 'Fecha y hora por confirmar';
  if (m.kickoffConfirmed == false) return '${_cap(footballFullDate(k))} · hora por confirmar';
  return '${_cap(footballFullDate(k))} · ${footballClock(k)} (hora de Lima)';
}

String _cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

/// SONIC_05: round number of "Regular Season - 11" / "Apertura - 11" (null otherwise).
int? footballRoundNumber(String? round) {
  final match = RegExp(r'-\s*(\d+)\s*$').firstMatch(round?.trim() ?? '');
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// SONIC_05 round selector data: rounds ordered by their earliest kickoff (not by array order).
class FootballRound {
  const FootballRound({required this.key, required this.label, required this.matches});
  final String key;
  final String label;
  final List<FootballMatch> matches;
  DateTime? get start => matches.map((m) => m.kickoff).whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
}

List<FootballRound> footballRounds(List<FootballMatch> items) {
  final order = <String>[];
  final map = <String, List<FootballMatch>>{};
  for (final m in items) {
    final key = (m.round?.trim().isNotEmpty ?? false) ? m.round!.trim() : '';
    map.putIfAbsent(key, () { order.add(key); return []; }).add(m);
  }
  final rounds = [
    for (final key in order)
      FootballRound(key: key, label: key.isEmpty ? 'Sin fecha asignada' : (map[key]!.first.roundLabel ?? key),
          matches: map[key]!),
  ];
  rounds.sort((a, b) {
    final x = a.start, y = b.start;
    if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
    return x.compareTo(y);
  });
  return rounds;
}

/// SONIC_05: active round = the featured team's next match round when listed; else the first round
/// (by start) with a live match or a pending match from today (Lima) on; else the first round with
/// anything pending; else the last round. Never simply the first element of the array.
String? footballActiveRound(List<FootballRound> rounds, {required DateTime limaNow, int? featuredNextId}) {
  if (rounds.isEmpty) return null;
  if (featuredNextId != null) {
    for (final r in rounds) {
      if (r.matches.any((m) => m.id == featuredNextId)) return r.key;
    }
  }
  final today = DateTime(limaNow.year, limaNow.month, limaNow.day);
  for (final r in rounds) {
    if (r.matches.any((m) => m.isLive && !m.isUnconfirmed)
        || r.matches.any((m) => m.isPending && m.kickoff != null && !m.kickoff!.isBefore(today))) {
      return r.key;
    }
  }
  for (final r in rounds) {
    if (r.matches.any((m) => m.isPending)) return r.key;
  }
  return rounds.last.key;
}

String? _crest(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return null;
  return value;
}

DateTime? _limaKickoff(Object? raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  return parsed == null ? null : limaWallClock(parsed);
}

String footballEventLabel(String? type, {String? detail}) {
  final d = detail?.toLowerCase() ?? '';
  return switch (type) {
    'GOAL' => d.contains('own goal') ? 'Autogol'
        : d.contains('missed penalty') ? 'Penal fallado'
        : d.contains('penalty') ? 'Gol de penal' : 'Gol',
    'YELLOW_CARD' => 'Tarjeta amarilla',
    'RED_CARD' => 'Tarjeta roja',
    'SUBSTITUTION' => 'Cambio',
    _ => 'Incidencia',
  };
}

/// SONIC_05: every provider statistic label in Spanish. Keys are normalized (lowercase, "_"/"-" as
/// spaces) so "Free Kicks", "free_kicks" and "Throw-ins" all resolve.
String footballStatLabel(String? type) {
  const labels = {
    'shots on goal': 'Remates al arco',
    'shots on target': 'Remates al arco',
    'shots off goal': 'Remates desviados',
    'shots off target': 'Remates desviados',
    'total shots': 'Remates totales',
    'blocked shots': 'Remates bloqueados',
    'shots insidebox': 'Remates dentro del área',
    'shots inside box': 'Remates dentro del área',
    'shots outsidebox': 'Remates fuera del área',
    'shots outside box': 'Remates fuera del área',
    'fouls': 'Faltas',
    'corner kicks': 'Tiros de esquina',
    'corners': 'Tiros de esquina',
    'offsides': 'Fueras de juego',
    'ball possession': 'Posesión',
    'possession': 'Posesión',
    'yellow cards': 'Tarjetas amarillas',
    'red cards': 'Tarjetas rojas',
    'goalkeeper saves': 'Atajadas',
    'saves': 'Atajadas',
    'total passes': 'Pases totales',
    'passes': 'Pases',
    'passes accurate': 'Pases precisos',
    'accurate passes': 'Pases precisos',
    'passes %': 'Precisión de pases',
    'pass accuracy': 'Precisión de pases',
    'expected goals': 'Goles esperados (xG)',
    'goals prevented': 'Goles evitados',
    'free kicks': 'Tiros libres',
    'goal kicks': 'Saques de arco',
    'throw ins': 'Saques de banda',
    'throw in': 'Saques de banda',
    'throwins': 'Saques de banda',
    'substitutions': 'Cambios',
    'attacks': 'Ataques',
    'dangerous attacks': 'Ataques peligrosos',
    'counter attacks': 'Contraataques',
    'penalties': 'Penales',
    'hit woodwork': 'Remates al palo',
    'crosses': 'Centros',
    'tackles': 'Entradas',
    'interceptions': 'Intercepciones',
    'clearances': 'Despejes',
    'duels won': 'Duelos ganados',
    'assists': 'Asistencias',
    'injuries': 'Lesiones',
    'goals': 'Goles',
  };
  final raw = type?.trim() ?? '';
  final key = raw.toLowerCase().replaceAll(RegExp(r'[_-]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  return labels[key] ?? (raw.isEmpty ? 'Dato' : raw);
}

/// SONIC_04: presentation-only stage label ("Primera División: Tabla Anual" → "Tabla anual").
/// The provider group stays the key; only the visible text changes.
String footballStageLabel(String? raw) {
  var value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Tabla';
  final colon = value.lastIndexOf(':');
  if (colon >= 0 && colon < value.length - 1) value = value.substring(colon + 1).trim();
  final lower = value.toLowerCase();
  if (lower.contains('apertura')) return 'Apertura';
  if (lower.contains('clausura')) return 'Clausura';
  if (lower.contains('anual') || lower.contains('annual')) return 'Tabla anual';
  if (lower.contains('acumulad') || lower.contains('aggregate') || lower.contains('overall')) {
    return 'Acumulada';
  }
  final group = RegExp(r'^group\s+([a-z0-9]+)$', caseSensitive: false).firstMatch(value);
  if (group != null) return 'Grupo ${group.group(1)!.toUpperCase()}';
  return value[0].toUpperCase() + value.substring(1);
}

/// SONIC_04: semantic event kind for the timeline (icon + color), from the
/// backend type plus provider detail. Unknown details stay a neutral incident.
enum FootballEventKind { goal, penaltyGoal, ownGoal, missedPenalty, yellow, secondYellow, red,
  substitution, videoReview, other }

FootballEventKind footballEventKind(String? type, {String? detail}) {
  final d = detail?.toLowerCase() ?? '';
  return switch (type) {
    'GOAL' => d.contains('own goal') ? FootballEventKind.ownGoal
        : d.contains('missed penalty') ? FootballEventKind.missedPenalty
        : d.contains('penalty') ? FootballEventKind.penaltyGoal : FootballEventKind.goal,
    'YELLOW_CARD' => d.contains('second yellow') ? FootballEventKind.secondYellow : FootballEventKind.yellow,
    'RED_CARD' => FootballEventKind.red,
    'SUBSTITUTION' => FootballEventKind.substitution,
    _ => (d.contains('var') || d.contains('cancelled') || d.contains('disallowed')
            || d.contains('confirmed')) ? FootballEventKind.videoReview : FootballEventKind.other,
  };
}

/// Minute + extra time order; stable for events in the same minute.
List<Map<String, dynamic>> sortFootballEvents(List<Map<String, dynamic>> events) {
  int minute(Map<String, dynamic> e) => (e['elapsed'] as num?)?.toInt() ?? 1 << 20;
  int extra(Map<String, dynamic> e) => (e['extra'] as num?)?.toInt() ?? 0;
  final indexed = [for (var i = 0; i < events.length; i++) (i, events[i])];
  indexed.sort((a, b) {
    final m = minute(a.$2).compareTo(minute(b.$2));
    if (m != 0) return m;
    final x = extra(a.$2).compareTo(extra(b.$2));
    return x != 0 ? x : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Latest provider event minute (elapsed + extra), or null.
(int, int)? latestEventMinute(List<Map<String, dynamic>> events) {
  (int, int)? best;
  for (final e in events) {
    final m = (e['elapsed'] as num?)?.toInt();
    if (m == null) continue;
    final x = (e['extra'] as num?)?.toInt() ?? 0;
    if (best == null || m > best.$1 || (m == best.$1 && x > best.$2)) best = (m, x);
  }
  return best;
}

/// SONIC_04: PARA TI hero from the backend (featured provider team id).
class FootballFeatured {
  const FootballFeatured({this.teamId, this.teamName, this.label, this.live, this.next,
    this.last, this.competitionIds = const []});
  final int? teamId;
  final String? teamName;
  final String? label;
  final FootballMatch? live;
  final FootballMatch? next;
  final FootballMatch? last;
  final List<String> competitionIds;

  /// Hero name: optional config label, else provider team name. Never hardcoded.
  String? get displayName {
    final l = label?.trim() ?? '';
    if (l.isNotEmpty) return l;
    final n = teamName?.trim() ?? '';
    return n.isEmpty ? null : n;
  }

  factory FootballFeatured.fromJson(Map<String, dynamic> json) {
    FootballMatch? m(Object? raw) => raw is Map<String, dynamic> ? FootballMatch.fromJson(raw) : null;
    return FootballFeatured(
      teamId: (json['teamId'] as num?)?.toInt(),
      teamName: json['teamName']?.toString(),
      label: json['label']?.toString(),
      live: m(json['live']),
      next: m(json['next']),
      last: m(json['last']),
      competitionIds: ((json['competitionIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

/// Standing stages from provider \`group\` — never concatenate ranks.
class FootballStandingStage {
  const FootballStandingStage({required this.name, required this.rows});
  final String name;
  final List<Map<String, dynamic>> rows;

  static List<FootballStandingStage> fromRows(List<Map<String, dynamic>> rows) {
    final order = <String>[];
    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final raw = row['group']?.toString().trim();
      final key = (raw == null || raw.isEmpty) ? 'Tabla' : raw;
      map.putIfAbsent(key, () {
        order.add(key);
        return <Map<String, dynamic>>[];
      }).add(row);
    }
    return [for (final name in order) FootballStandingStage(name: name, rows: map[name]!)];
  }
}

class FootballPage<T> {
  const FootballPage({required this.items, required this.stale,
    required this.unavailable, required this.partial, this.reason});
  final List<T> items;
  final bool stale;
  final bool unavailable;
  final bool partial;
  final String? reason;

  factory FootballPage.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) => FootballPage(
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>().map(parse).toList(),
    stale: json['stale'] == true,
    unavailable: json['unavailable'] == true,
    partial: json['partial'] == true,
    reason: json['reason'] is String ? json['reason'] as String : null,
  );
}

class FootballDetail {
  const FootballDetail({required this.match, required this.events,
    required this.lineups, required this.statistics, required this.partial,
    required this.stale});
  final FootballMatch match;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> lineups;
  final List<Map<String, dynamic>> statistics;
  final bool partial;
  final bool stale;

  factory FootballDetail.fromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['item'] as Map<String, dynamic>;
    return FootballDetail(
      match: FootballMatch.fromJson(data['match'] as Map<String, dynamic>),
      events: _maps(data['events']),
      lineups: _maps(data['lineups']),
      statistics: _maps(data['statistics']),
      partial: data['partial'] == true,
      stale: envelope['stale'] == true,
    );
  }

  static List<Map<String, dynamic>> _maps(dynamic value) =>
      ((value as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
}

/// SONIC_05: lineup card (numbered XI and bench). Falls back to the names-only lists of older answers.
class FootballLineupPlayer {
  const FootballLineupPlayer({required this.name, this.number, this.position});
  final String name;
  final int? number;
  final String? position;

  String? get positionLabel => switch (position?.toUpperCase()) {
    'G' => 'ARQ',
    'D' => 'DEF',
    'M' => 'MED',
    'F' => 'DEL',
    _ => null,
  };
}

class FootballLineup {
  const FootballLineup({required this.team, this.teamId, this.crestUrl, this.formation, this.coach,
    this.starting = const [], this.bench = const []});
  final String team;
  final int? teamId;
  final String? crestUrl;
  final String? formation;
  final String? coach;
  final List<FootballLineupPlayer> starting;
  final List<FootballLineupPlayer> bench;

  factory FootballLineup.fromJson(Map<String, dynamic> json) {
    List<FootballLineupPlayer> players(Object? detailed, Object? names) {
      final list = (detailed as List?)?.whereType<Map>().map((p) => FootballLineupPlayer(
            name: p['name']?.toString() ?? 'Jugador',
            number: (p['number'] as num?)?.toInt(),
            position: _text(p['position']))).toList() ?? const <FootballLineupPlayer>[];
      if (list.isNotEmpty) return list;
      return ((names as List?) ?? const []).map((n) => FootballLineupPlayer(name: n.toString())).toList();
    }
    return FootballLineup(
      team: _text(json['team']) ?? 'Equipo',
      teamId: (json['teamId'] as num?)?.toInt(),
      crestUrl: _crest(json['crestUrl']),
      formation: _text(json['formation']),
      coach: _text(json['coach']),
      starting: players(json['startXI'], json['starting']),
      bench: players(json['bench'], json['substitutes']),
    );
  }
}

/// SONIC_05 Team Center (any provider team id), from the backend cache-only endpoint.
class FootballTeamCenter {
  const FootballTeamCenter({required this.teamId, this.name, this.crestUrl, this.competition,
    this.live, this.next, this.last, this.matches = const [], this.partial = false});
  final int teamId;
  final String? name;
  final String? crestUrl;
  final String? competition;
  final FootballMatch? live;
  final FootballMatch? next;
  final FootballMatch? last;
  final List<FootballMatch> matches;
  final bool partial;

  factory FootballTeamCenter.fromJson(Map<String, dynamic> json) {
    FootballMatch? m(Object? raw) => raw is Map<String, dynamic> ? FootballMatch.fromJson(raw) : null;
    return FootballTeamCenter(
      teamId: (json['teamId'] as num?)?.toInt() ?? 0,
      name: _text(json['name']),
      crestUrl: _crest(json['crestUrl']),
      competition: _text(json['competition']),
      live: m(json['live']),
      next: m(json['next']),
      last: m(json['last']),
      matches: ((json['matches'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>().map(FootballMatch.fromJson).toList(),
      partial: json['partial'] == true,
    );
  }
}

/// Team Center answer: [center] null with [unavailable] (no cached calendar) or a [reason].
class FootballTeamCenterResult {
  const FootballTeamCenterResult({this.center, this.unavailable = false, this.stale = false, this.reason});
  final FootballTeamCenter? center;
  final bool unavailable;
  final bool stale;
  final String? reason;
}
