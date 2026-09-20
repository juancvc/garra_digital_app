class CheckInModel {
  const CheckInModel({
    required this.id,
    required this.cremaPointId,
    required this.cremaPointName,
    this.cremaPointType,
    this.cremaPointAddress,
    required this.distanceMeters,
    required this.pointsEarned,
    this.awardedPoints,
    required this.status,
    required this.createdAt,
    this.valid,
    this.matchLinked = false,
    this.matchId,
    this.newBalance,
    this.checkinRadiusMeters,
  });

  final String id;
  final String cremaPointId;
  final String cremaPointName;
  final String? cremaPointType;
  final String? cremaPointAddress;
  final double distanceMeters;
  final int pointsEarned;
  final int? awardedPoints;
  final String status;
  final String createdAt;
  final bool? valid;
  final bool matchLinked;
  final String? matchId;
  final int? newBalance;
  final int? checkinRadiusMeters;

  /// Prefer awardedPoints when present (check-in 2.0), else pointsEarned.
  int get displayPoints => awardedPoints ?? pointsEarned;

  factory CheckInModel.fromJson(Map<String, dynamic> json) {
    final awarded = (json['awardedPoints'] as num?)?.toInt();
    final earned = (json['pointsEarned'] as num?)?.toInt() ?? 0;

    return CheckInModel(
      id: json['id']?.toString() ?? '',
      cremaPointId: json['cremaPointId']?.toString() ?? '',
      cremaPointName: json['cremaPointName']?.toString() ?? '',
      cremaPointType: json['cremaPointType']?.toString(),
      cremaPointAddress: json['cremaPointAddress']?.toString(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      pointsEarned: earned,
      awardedPoints: awarded,
      status: json['status']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      valid: json['valid'] as bool?,
      matchLinked: json['matchLinked'] as bool? ?? false,
      matchId: json['matchId']?.toString(),
      newBalance: (json['newBalance'] as num?)?.toInt(),
      checkinRadiusMeters: (json['checkinRadiusMeters'] as num?)?.toInt(),
    );
  }
}
