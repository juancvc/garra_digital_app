class PredictionModel {
  final String predictionId;
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  final String matchDateTime;
  final String matchStatus;
  final int predictedHomeScore;
  final int predictedAwayScore;
  final String? predictedFirstScorer;
  final int pointsEarned;
  final String predictionStatus;

  PredictionModel({
    required this.predictionId,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchDateTime,
    required this.matchStatus,
    required this.predictedHomeScore,
    required this.predictedAwayScore,
    required this.predictedFirstScorer,
    required this.pointsEarned,
    required this.predictionStatus,
  });

  int get homeScore => predictedHomeScore;

  int get awayScore => predictedAwayScore;

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      predictionId: json['predictionId'],
      matchId: json['matchId'],
      homeTeam: json['homeTeam'],
      awayTeam: json['awayTeam'],
      matchDateTime: json['matchDateTime'],
      matchStatus: json['matchStatus'],
      predictedHomeScore: json['predictedHomeScore'],
      predictedAwayScore: json['predictedAwayScore'],
      predictedFirstScorer: json['predictedFirstScorer'],
      pointsEarned: json['pointsEarned'] ?? 0,
      predictionStatus: json['predictionStatus'],
    );
  }
}