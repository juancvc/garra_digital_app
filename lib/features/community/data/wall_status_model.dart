class WallStatusModel {
  const WallStatusModel({
    required this.matchId,
    required this.matchName,
    required this.matchDateTime,
    required this.wallStatus,
    required this.opensAt,
    required this.closesAt,
    required this.secondsToOpen,
    required this.secondsToClose,
  });

  final String? matchId;
  final String? matchName;
  final String? matchDateTime;
  final String wallStatus;
  final String? opensAt;
  final String? closesAt;
  final int secondsToOpen;
  final int secondsToClose;

  factory WallStatusModel.fromJson(Map<String, dynamic> json) {
    return WallStatusModel(
      matchId: json['matchId']?.toString(),
      matchName: json['matchName']?.toString(),
      matchDateTime: json['matchDateTime']?.toString(),
      wallStatus: json['wallStatus']?.toString() ?? '',
      opensAt: json['opensAt']?.toString(),
      closesAt: json['closesAt']?.toString(),
      secondsToOpen: (json['secondsToOpen'] as num?)?.toInt() ?? 0,
      secondsToClose: (json['secondsToClose'] as num?)?.toInt() ?? 0,
    );
  }
}