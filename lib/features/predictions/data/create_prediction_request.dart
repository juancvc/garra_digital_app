class CreatePredictionRequest {
  CreatePredictionRequest({
    required this.matchId,
    required this.predictedHomeScore,
    required this.predictedAwayScore,
    this.predictedFirstScorer,
  });

  final String matchId;
  final int predictedHomeScore;
  final int predictedAwayScore;
  final String? predictedFirstScorer;

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'predictedHomeScore': predictedHomeScore,
      'predictedAwayScore': predictedAwayScore,
      'predictedFirstScorer': predictedFirstScorer,
    };
  }
}