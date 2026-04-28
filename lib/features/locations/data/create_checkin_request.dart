class CreateCheckInRequest {
  const CreateCheckInRequest({
    required this.cremaPointId,
    required this.latitude,
    required this.longitude,
  });

  final String cremaPointId;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() {
    return {
      'cremaPointId': cremaPointId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}