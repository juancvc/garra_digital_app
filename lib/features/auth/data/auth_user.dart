class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
    required this.username,
    required this.fullName,
    required this.status,
    this.role = 'USER',
  });

  final String userId;
  final String email;
  final String username;
  final String fullName;
  final String status;
  final String role;

  String get id => userId;

  bool get isAdmin {
    final r = role.toUpperCase();
    return r == 'ADMIN' || r == 'SUPERADMIN';
  }

  bool get isSuperAdmin => role.toUpperCase() == 'SUPERADMIN';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      // Login/refresh send `userId`; GET /auth/me (AuthMeResponse) sends `id`.
      userId: (json['userId'] ?? json['id'])?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      role: (json['role'] ?? json['platformRole'] ?? 'USER').toString(),
    );
  }
}
