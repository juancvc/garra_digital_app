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
  const FootballCompetition({required this.id, required this.name, required this.available});
  final String id;
  final String name;
  final bool available;
  factory FootballCompetition.fromJson(Map<String, dynamic> json) => FootballCompetition(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    available: json['available'] == true,
  );
}

class FootballMatch {
  const FootballMatch({required this.id, required this.competitionId,
    required this.competition, required this.home, required this.away,
    required this.status, this.kickoff, this.elapsed, this.homeScore,
    this.awayScore, this.garraMatchId, this.round});
  final int id;
  final String competitionId;
  final String competition;
  final String home;
  final String away;
  final String status;
  final DateTime? kickoff;
  final int? elapsed;
  final int? homeScore;
  final int? awayScore;
  final String? garraMatchId;
  final String? round;

  factory FootballMatch.fromJson(Map<String, dynamic> json) => FootballMatch(
    id: (json['id'] as num?)?.toInt() ?? 0,
    competitionId: json['competitionId']?.toString() ?? '',
    competition: json['competition']?.toString() ?? '',
    home: (json['home'] as Map?)?['name']?.toString() ?? 'Por confirmar',
    away: (json['away'] as Map?)?['name']?.toString() ?? 'Por confirmar',
    status: json['status']?.toString() ?? 'UNKNOWN',
    kickoff: _limaKickoff(json['kickoff']),
    elapsed: (json['elapsed'] as num?)?.toInt(),
    homeScore: (json['homeScore'] as num?)?.toInt(),
    awayScore: (json['awayScore'] as num?)?.toInt(),
    garraMatchId: json['garraMatchId']?.toString(),
    round: json['round']?.toString(),
  );

  bool get isLive => status == 'LIVE';
  bool get isFinished => status == 'FINISHED';
  bool get isScheduled => status == 'SCHEDULED';

  /// Product round label: provider "Regular Season - 12" becomes "Fecha 12";
  /// tournament names ("Apertura - 3") keep their own words.
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

  String get statusLabel => switch (status) {
    'LIVE' => elapsed == null ? 'EN VIVO' : "${elapsed!}′ EN VIVO",
    'FINISHED' => 'FINALIZADO',
    'POSTPONED' => 'POSTERGADO',
    'CANCELLED' => 'CANCELADO',
    'SCHEDULED' => 'PROGRAMADO',
    _ => 'ESTADO POR CONFIRMAR',
  };
}

DateTime? _limaKickoff(Object? raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  return parsed == null ? null : limaWallClock(parsed);
}

/// Spanish label for the Garra event kinds (never the raw code).
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

/// Spanish names for the statistics Garra receives from its data source;
/// unknown names are shown as received (already human-readable text).
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

class FootballPage<T> {
  const FootballPage({required this.items, required this.stale,
    required this.unavailable, required this.partial, this.reason});
  final List<T> items;
  final bool stale;
  /// Nothing could be loaded. Empty [items] with `unavailable == false` is a
  /// valid empty answer (no matches today, no table yet), never an outage.
  final bool unavailable;
  /// Some competitions failed; what is shown is still valid.
  final bool partial;
  /// SONIC_01B: coarse backend layer when something failed or is stale
  /// (CONFIG, CACHE, PROVIDER_BUSY, PROVIDER_COOLDOWN, BUDGET, PROVIDER,
  /// INTERNAL). Diagnostics only: never shown to the user.
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
