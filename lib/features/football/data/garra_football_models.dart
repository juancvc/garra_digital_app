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
    this.featured = false, this.snapshotAt, this.dataState});
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
      featured: featured, snapshotAt: snapshotAt, dataState: 'UNCONFIRMED');

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
    );
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

String footballStatLabel(String? type) {
  const labels = {
    'shots on goal': 'Remates al arco',
    'shots off goal': 'Remates desviados',
    'total shots': 'Remates totales',
    'blocked shots': 'Remates bloqueados',
    'shots insidebox': 'Remates dentro del área',
    'shots outsidebox': 'Remates fuera del área',
    'fouls': 'Faltas',
    'corner kicks': 'Tiros de esquina',
    'offsides': 'Fueras de juego',
    'ball possession': 'Posesión',
    'yellow cards': 'Tarjetas amarillas',
    'red cards': 'Tarjetas rojas',
    'goalkeeper saves': 'Atajadas',
    'total passes': 'Pases totales',
    'passes accurate': 'Pases precisos',
    'passes %': 'Precisión de pases',
    'expected_goals': 'Goles esperados (xG)',
    'goals_prevented': 'Goles evitados',
  };
  final raw = type?.trim() ?? '';
  return labels[raw.toLowerCase()] ?? (raw.isEmpty ? 'Dato' : raw);
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
