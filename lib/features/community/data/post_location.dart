class PostLocation {
  const PostLocation({required this.name, required this.kind,
    this.latitude, this.longitude});

  final String name;
  final String kind;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  factory PostLocation.fromJson(Map<String, dynamic> json) => PostLocation(
    name: json['name']?.toString() ?? '',
    kind: json['kind']?.toString() ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}
