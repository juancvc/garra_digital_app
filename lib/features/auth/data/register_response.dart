import 'auth_flow_models.dart';

/// Body of POST /auth/register (`data`). The tokens are intentionally not
/// modelled: while [verificationRequired] is true the server issues none.
class RegisterResponse {
  const RegisterResponse({
    required this.verificationRequired,
    required this.email,
    required this.emailMasked,
    required this.resendAvailableInSeconds,
    required this.codeExpiresInSeconds,
  });

  final bool verificationRequired;
  final String email;
  final String emailMasked;
  final int resendAvailableInSeconds;
  final int codeExpiresInSeconds;

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    final email = json['email']?.toString() ?? '';
    return RegisterResponse(
      // Typed flag; a legacy response without it carries a session instead.
      verificationRequired: json['verificationRequired'] == true,
      email: email,
      emailMasked: json['emailMasked']?.toString() ?? maskEmail(email),
      resendAvailableInSeconds: resendSecondsFrom(
        json['resendAvailableInSeconds'],
      ),
      codeExpiresInSeconds: codeSecondsFrom(json['codeExpiresInSeconds']),
    );
  }
}
