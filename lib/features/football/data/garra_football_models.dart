enum FootballView { today, live, upcoming, results }

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
    kickoff: DateTime.tryParse(json['kickoff']?.toString() ?? '')?.toLocal(),
    elapsed: (json['elapsed'] as num?)?.toInt(),
    homeScore: (json['homeScore'] as num?)?.toInt(),
    awayScore: (json['awayScore'] as num?)?.toInt(),
    garraMatchId: json['garraMatchId']?.toString(),
    round: json['round']?.toString(),
  );

  String get statusLabel => switch (status) {
    'LIVE' => elapsed == null ? 'EN VIVO' : "${elapsed!}′ EN VIVO",
    'FINISHED' => 'FINALIZADO',
    'POSTPONED' => 'POSTERGADO',
    'CANCELLED' => 'CANCELADO',
    'SCHEDULED' => 'PROGRAMADO',
    _ => 'ESTADO POR CONFIRMAR',
  };
}

class FootballPage<T> {
  const FootballPage({required this.items, required this.stale,
    required this.unavailable, required this.partial});
  final List<T> items;
  final bool stale;
  final bool unavailable;
  final bool partial;

  factory FootballPage.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) => FootballPage(
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>().map(parse).toList(),
    stale: json['stale'] == true,
    unavailable: json['unavailable'] == true,
    partial: json['partial'] == true,
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
