class CreateCheckInRequest {
  const CreateCheckInRequest({
    required this.cremaPointId,
    required this.latitude,
    required this.longitude,
    this.matchId,
    this.accuracyMeters,
  });

  final String cremaPointId;
  final double latitude;
  final double longitude;
  final String? matchId;
  final double? accuracyMeters;

  Map<String, dynamic> toJson() {
    return {
      'cremaPointId': cremaPointId,
      'latitude': latitude,
      'longitude': longitude,
      if (matchId != null && matchId!.isNotEmpty) 'matchId': matchId,
      if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
    };
  }
}
