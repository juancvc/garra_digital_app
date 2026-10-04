/// GARRA39.1: e-mail registration only proves identity. The Garra profile
/// (visible name, @usuario, tribuna) is chosen afterwards, so everything but
/// e-mail and password is optional (and omitted from the payload when absent).
class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    this.username,
    this.fullName,
    this.favoriteStand,
  });

  final String email;
  final String password;
  final String? username;
  final String? fullName;
  final String? favoriteStand;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      if (username != null) 'username': username,
      if (fullName != null) 'fullName': fullName,
      if (favoriteStand != null) 'favoriteStand': favoriteStand,
    };
  }
}
