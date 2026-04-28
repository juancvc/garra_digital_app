class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
    required this.username,
    required this.fullName,
    required this.status,
  });

  final String userId;
  final String email;
  final String username;
  final String fullName;
  final String status;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}