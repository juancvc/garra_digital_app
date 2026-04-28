class CheckInModel {
  const CheckInModel({
    required this.id,
    required this.cremaPointId,
    required this.cremaPointName,
    required this.cremaPointType,
    required this.cremaPointAddress,
    required this.distanceMeters,
    required this.pointsEarned,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String cremaPointId;
  final String cremaPointName;
  final String? cremaPointType;
  final String? cremaPointAddress;
  final double distanceMeters;
  final int pointsEarned;
  final String status;
  final String createdAt;

  factory CheckInModel.fromJson(Map<String, dynamic> json) {
    return CheckInModel(
      id: json['id']?.toString() ?? '',
      cremaPointId: json['cremaPointId']?.toString() ?? '',
      cremaPointName: json['cremaPointName']?.toString() ?? '',
      cremaPointType: json['cremaPointType']?.toString(),
      cremaPointAddress: json['cremaPointAddress']?.toString(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}