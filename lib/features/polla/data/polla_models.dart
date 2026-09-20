class PollaResponse {
  const PollaResponse({
    required this.match,
    required this.state,
    this.closesAt,
    required this.participants,
    this.myPrediction,
    required this.rules,
    required this.sentiment,
  });

  final PollaMatchInfo match;
  final String state;
  final DateTime? closesAt;
  final int participants;
  final PollaMyPrediction? myPrediction;
  final PollaRulesInfo rules;
  final PollaSentiment sentiment;

  bool get isOpen => state == 'OPEN';
  bool get isSubmitted => state == 'SUBMITTED';
  bool get isLocked => state == 'LOCKED';
  bool get isScored => state == 'SCORED';
  bool get isNotOpen => state == 'NOT_OPEN';
  bool get canEdit => isOpen || isSubmitted;

  factory PollaResponse.fromJson(Map<String, dynamic> json) {
    return PollaResponse(
      match: PollaMatchInfo.fromJson(
        Map<String, dynamic>.from(json['match'] as Map? ?? const {}),
      ),
      state: json['state'] as String? ?? 'NOT_OPEN',
      closesAt: _parseDate(json['closesAt']),
      participants: (json['participants'] as num?)?.toInt() ?? 0,
      myPrediction: json['myPrediction'] == null
          ? null
          : PollaMyPrediction.fromJson(
              Map<String, dynamic>.from(json['myPrediction'] as Map),
            ),
      rules: PollaRulesInfo.fromJson(
        Map<String, dynamic>.from(json['rules'] as Map? ?? const {}),
      ),
      sentiment: PollaSentiment.fromJson(
        Map<String, dynamic>.from(json['sentiment'] as Map? ?? const {}),
      ),
    );
  }
}

class PollaMatchInfo {
  const PollaMatchInfo({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchDateTime,
    required this.stadium,
    required this.competition,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.firstScorer,
    this.predictionClosesAt,
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime matchDateTime;
  final String stadium;
  final String competition;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final String? firstScorer;
  final DateTime? predictionClosesAt;

  factory PollaMatchInfo.fromJson(Map<String, dynamic> json) {
    return PollaMatchInfo(
      id: json['id'].toString(),
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      matchDateTime: _parseDate(json['matchDateTime']) ?? DateTime.now(),
      stadium: json['stadium'] as String? ?? '',
      competition: json['competition'] as String? ?? '',
      status: json['status']?.toString() ?? '',
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
      firstScorer: json['firstScorer'] as String?,
      predictionClosesAt: _parseDate(json['predictionClosesAt']),
    );
  }
}

class PollaMyPrediction {
  const PollaMyPrediction({
    this.homeScore,
    this.awayScore,
    this.firstScorer,
    this.status,
    this.pointsEarned,
    this.breakdown,
  });

  final int? homeScore;
  final int? awayScore;
  final String? firstScorer;
  final String? status;
  final int? pointsEarned;
  final PollaBreakdown? breakdown;

  bool get hasScores => homeScore != null && awayScore != null;

  factory PollaMyPrediction.fromJson(Map<String, dynamic> json) {
    return PollaMyPrediction(
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
      firstScorer: json['firstScorer'] as String?,
      status: json['status']?.toString(),
      pointsEarned: (json['pointsEarned'] as num?)?.toInt(),
      breakdown: json['breakdown'] == null
          ? null
          : PollaBreakdown.fromJson(
              Map<String, dynamic>.from(json['breakdown'] as Map),
            ),
    );
  }
}

class PollaBreakdown {
  const PollaBreakdown({
    required this.exactScorePoints,
    required this.outcomePoints,
    required this.firstScorerPoints,
    required this.totalPoints,
    required this.exactScoreHit,
    required this.outcomeHit,
    required this.firstScorerHit,
  });

  final int exactScorePoints;
  final int outcomePoints;
  final int firstScorerPoints;
  final int totalPoints;
  final bool exactScoreHit;
  final bool outcomeHit;
  final bool firstScorerHit;

  factory PollaBreakdown.fromJson(Map<String, dynamic> json) {
    return PollaBreakdown(
      exactScorePoints: (json['exactScorePoints'] as num?)?.toInt() ?? 0,
      outcomePoints: (json['outcomePoints'] as num?)?.toInt() ?? 0,
      firstScorerPoints: (json['firstScorerPoints'] as num?)?.toInt() ?? 0,
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      exactScoreHit: json['exactScoreHit'] as bool? ?? false,
      outcomeHit: json['outcomeHit'] as bool? ?? false,
      firstScorerHit: json['firstScorerHit'] as bool? ?? false,
    );
  }
}

class PollaRulesInfo {
  const PollaRulesInfo({
    required this.exactScorePoints,
    required this.outcomePoints,
    required this.firstScorerPoints,
    this.note,
  });

  final int exactScorePoints;
  final int outcomePoints;
  final int firstScorerPoints;
  final String? note;

  factory PollaRulesInfo.fromJson(Map<String, dynamic> json) {
    return PollaRulesInfo(
      exactScorePoints: (json['exactScorePoints'] as num?)?.toInt() ?? 5,
      outcomePoints: (json['outcomePoints'] as num?)?.toInt() ?? 3,
      firstScorerPoints: (json['firstScorerPoints'] as num?)?.toInt() ?? 4,
      note: json['note'] as String?,
    );
  }
}

class PollaSentiment {
  const PollaSentiment({
    required this.homeWinPercent,
    required this.drawPercent,
    required this.awayWinPercent,
    required this.totalPredictions,
  });

  final int homeWinPercent;
  final int drawPercent;
  final int awayWinPercent;
  final int totalPredictions;

  factory PollaSentiment.fromJson(Map<String, dynamic> json) {
    return PollaSentiment(
      homeWinPercent: (json['homeWinPercent'] as num?)?.toInt() ?? 0,
      drawPercent: (json['drawPercent'] as num?)?.toInt() ?? 0,
      awayWinPercent: (json['awayWinPercent'] as num?)?.toInt() ?? 0,
      totalPredictions: (json['totalPredictions'] as num?)?.toInt() ?? 0,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString();
  if (text.isEmpty) return null;
  try {
    return DateTime.parse(text);
  } catch (_) {
    return null;
  }
}
