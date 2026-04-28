class RankingModel {
  final int position;
  final String userId;
  final String username;
  final String fullName;
  final String favoriteStand;
  final int loyaltyPoints;

  RankingModel({
    required this.position,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.favoriteStand,
    required this.loyaltyPoints,
  });

  factory RankingModel.fromJson(Map<String, dynamic> json) {
    return RankingModel(
      position: json['position'] ?? 0,
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      favoriteStand: json['favoriteStand'] ?? '',
      loyaltyPoints: json['loyaltyPoints'] ?? 0,
    );
  }
}