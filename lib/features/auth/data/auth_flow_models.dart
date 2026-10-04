import 'package:dio/dio.dart';

/// GARRA39: typed outcomes of the account flows (register, verify, resend,
/// forgot, reset). Screens branch on [AuthFailureKind], never on message text.
enum AuthFailureKind {
  network,
  rateLimited,
  invalidCode,
  emailVerificationRequired,
  conflict,
  validation,
  emailUnavailable,
  server,
  unknown,
}

const authRateLimitedMessage =
    'Has hecho varios intentos. Intenta nuevamente en unos minutos.';
const authNetworkMessage =
    'No pudimos conectarnos. Revisa tu conexi\u00f3n e int\u00e9ntalo de nuevo.';
const authInvalidCodeMessage =
    'El c\u00f3digo no es v\u00e1lido o ya venci\u00f3. Solicita uno nuevo si lo necesitas.';
const authServerMessage =
    'No pudimos completar la acci\u00f3n ahora. Int\u00e9ntalo de nuevo en unos minutos.';
const authEmailUnavailableMessage =
    'El registro con correo a\u00fan no est\u00e1 disponible. Usa Google para entrar.';

/// GARRA39.1: the stand/tribuna choices of the Garra profile. The backend stores the label as free text
/// (there is no server catalog); this is the single client list, shared by every screen that asks for it.
const garraStands = <String>['Norte', 'Oriente', 'Occidente', 'Sur'];

/// Internal display name the backend gives a registration that has not chosen its Garra profile yet.
const pendingFullNamePlaceholder = 'Hincha Garra';

const authUsernameTakenMessage =
    'Ese nombre de usuario ya est\u00e1 en uso. Prueba con otro.';
const authUnknownMessage = 'Ocurri\u00f3 un error inesperado';
const authNeutralAcceptedMessage =
    'Si existe una cuenta asociada, enviaremos las instrucciones.';

class AuthFlowResult<T> {
  const AuthFlowResult._({
    required this.success,
    required this.message,
    this.data,
    this.kind,
    this.retryAfterSeconds,
  });

  factory AuthFlowResult.success({T? data, String message = ''}) =>
      AuthFlowResult._(success: true, message: message, data: data);

  factory AuthFlowResult.failure(
    AuthFailureKind kind,
    String message, {
    int? retryAfterSeconds,
  }) => AuthFlowResult._(
    success: false,
    message: message,
    kind: kind,
    retryAfterSeconds: retryAfterSeconds,
  );

  final bool success;
  final String message;
  final T? data;
  final AuthFailureKind? kind;

  /// Seconds from the `Retry-After` header of a 429, when the server sent one.
  final int? retryAfterSeconds;
}

/// What the client needs after POST /auth/register. Never carries a code,
/// password or token.
class RegisterOutcome {
  const RegisterOutcome({
    required this.verificationRequired,
    required this.email,
    required this.resendAvailableInSeconds,
    required this.codeExpiresInSeconds,
  });

  final bool verificationRequired;
  final String email;
  final int resendAvailableInSeconds;
  final int codeExpiresInSeconds;
}

class ResendAck {
  const ResendAck({
    required this.resendAvailableInSeconds,
    required this.codeExpiresInSeconds,
  });

  final int resendAvailableInSeconds;
  final int codeExpiresInSeconds;
}

/// `juan@gmail.com` -> `j***@gmail.com`.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return '***';
  return '${email[0]}***${email.substring(at)}';
}

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int resendSecondsFrom(Object? value) => _asInt(value, 60);
int codeSecondsFrom(Object? value) => _asInt(value, 600);

/// Maps a failed account-flow request to a typed result. [fallback] is the
/// Spanish copy for validation/unknown 4xx without a friendlier translation.
AuthFlowResult<T> authFailureFromDio<T>(
  DioException e, {
  required String fallback,
}) {
  final status = e.response?.statusCode;
  if (status == null) {
    return AuthFlowResult.failure(AuthFailureKind.network, authNetworkMessage);
  }
  final body = e.response?.data;
  final backendMessage = body is Map ? body['message']?.toString() : null;
  final errors = body is Map ? body['errors'] : null;
  final code = errors is Map ? errors['code']?.toString() : null;

  if (status == 429) {
    final header = e.response?.headers.value('retry-after');
    final retry = int.tryParse(header?.trim() ?? '');
    return AuthFlowResult.failure(
      AuthFailureKind.rateLimited,
      authRateLimitedMessage,
      retryAfterSeconds: retry != null && retry > 0 ? retry : null,
    );
  }
  if (code == 'EMAIL_VERIFICATION_REQUIRED') {
    return AuthFlowResult.failure(
      AuthFailureKind.emailVerificationRequired,
      'Debes verificar tu correo para continuar.',
    );
  }
  if (code == 'EMAIL_DELIVERY_UNAVAILABLE') {
    return AuthFlowResult.failure(
      AuthFailureKind.emailUnavailable,
      authEmailUnavailableMessage,
    );
  }
  if (code == 'INVALID_CODE') {
    return AuthFlowResult.failure(
      AuthFailureKind.invalidCode,
      authInvalidCodeMessage,
    );
  }
  if (status >= 500) {
    return AuthFlowResult.failure(AuthFailureKind.server, authServerMessage);
  }

  final lower = (backendMessage ?? '').toLowerCase();
  if (lower.contains('email is already registered')) {
    return AuthFlowResult.failure(
      AuthFailureKind.conflict,
      'Este correo ya est\u00e1 registrado',
    );
  }
  if (lower.contains('username is already registered')) {
    return AuthFlowResult.failure(
      AuthFailureKind.conflict,
      'Este nombre de usuario ya est\u00e1 registrado',
    );
  }
  if (lower.contains('password')) {
    return AuthFlowResult.failure(
      AuthFailureKind.validation,
      'La contrase\u00f1a debe tener entre 8 y 120 caracteres.',
    );
  }
  return AuthFlowResult.failure(AuthFailureKind.validation, fallback);
}
