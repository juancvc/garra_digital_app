class RegisterResponse {
  const RegisterResponse({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.favoriteStand,
    required this.status,
  });

  final String id;
  final String email;
  final String username;
  final String fullName;
  final String favoriteStand;
  final String status;

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      favoriteStand: json['favoriteStand']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}