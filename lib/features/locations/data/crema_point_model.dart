class CremaPointModel {
  const CremaPointModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.verified,
    required this.sponsor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.checkinRadiusMeters = 500,
  });

  final String id;
  final String name;
  final String? description;
  final String type;
  final String address;
  final double latitude;
  final double longitude;
  final bool verified;
  final bool sponsor;
  final String status;
  final String createdAt;
  final String updatedAt;
  final int checkinRadiusMeters;

  factory CremaPointModel.fromJson(Map<String, dynamic> json) {
    return CremaPointModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      type: json['type']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      verified: json['verified'] as bool? ?? false,
      sponsor: json['sponsor'] as bool? ?? false,
      status: json['status']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      checkinRadiusMeters:
          (json['checkinRadiusMeters'] as num?)?.toInt() ?? 500,
    );
  }
}