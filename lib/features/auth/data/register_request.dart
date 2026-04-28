class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.username,
    required this.password,
    required this.fullName,
    required this.favoriteStand,
  });

  final String email;
  final String username;
  final String password;
  final String fullName;
  final String favoriteStand;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'password': password,
      'fullName': fullName,
      'favoriteStand': favoriteStand,
    };
  }
}