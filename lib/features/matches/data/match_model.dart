class MatchModel {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String matchDateTime;
  final String stadium;
  final String competition;
  final String status;
  final String? predictionClosesAt;

  MatchModel({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchDateTime,
    required this.stadium,
    required this.competition,
    required this.status,
    this.predictionClosesAt,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'],
      homeTeam: json['homeTeam'],
      awayTeam: json['awayTeam'],
      matchDateTime: json['matchDateTime'],
      stadium: json['stadium'],
      competition: json['competition'],
      status: json['status'],
      predictionClosesAt: json['predictionClosesAt'],
    );
  }
}