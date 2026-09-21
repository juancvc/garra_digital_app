import 'package:dio/dio.dart';

/// Human-readable Dio error classification for UI.
enum GarraErrorKind {
  offline,
  timeout,
  session,
  forbidden,
  notFound,
  conflict,
  rateLimited,
  server,
  maintenance,
  upgradeRequired,
  unknown,
}

class GarraErrorInfo {
  const GarraErrorInfo(this.kind, this.message);
  final GarraErrorKind kind;
  final String message;
}

GarraErrorInfo classifyDioError(Object error) {
  if (error is! DioException) {
    return const GarraErrorInfo(
      GarraErrorKind.unknown,
      'No pudimos completar la acción.',
    );
  }
  final e = error;
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.unknown && e.response == null) {
    return const GarraErrorInfo(
      GarraErrorKind.offline,
      'Parece que estás sin conexión.',
    );
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return const GarraErrorInfo(
      GarraErrorKind.timeout,
      'La conexión tardó demasiado. Intenta nuevamente.',
    );
  }
  final code = e.response?.statusCode;
  if (code == 401) {
    return const GarraErrorInfo(
      GarraErrorKind.session,
      'Tu sesión expiró. Vuelve a iniciar sesión.',
    );
  }
  if (code == 403) {
    return const GarraErrorInfo(
      GarraErrorKind.forbidden,
      'No tienes permiso para esta acción.',
    );
  }
  if (code == 404) {
    return const GarraErrorInfo(
      GarraErrorKind.notFound,
      'No encontramos lo que buscabas.',
    );
  }
  if (code == 409) {
    return const GarraErrorInfo(
      GarraErrorKind.conflict,
      'Esta acción no se puede completar ahora.',
    );
  }
  if (code == 429) {
    return const GarraErrorInfo(
      GarraErrorKind.rateLimited,
      'Garra está recibiendo muchas solicitudes. Intenta nuevamente.',
    );
  }
  if (code == 503) {
    final body = e.response?.data;
    if (body is Map && body['message']?.toString().toLowerCase().contains('manten') == true) {
      return const GarraErrorInfo(
        GarraErrorKind.maintenance,
        'Estamos preparando la tribuna.',
      );
    }
  }
  if (code == 426) {
    return const GarraErrorInfo(
      GarraErrorKind.upgradeRequired,
      'Actualiza Garra para continuar.',
    );
  }
  if (code != null && code >= 500) {
    return const GarraErrorInfo(
      GarraErrorKind.server,
      'No pudimos cargar esto ahora.',
    );
  }
  return const GarraErrorInfo(
    GarraErrorKind.unknown,
    'No pudimos completar la acción.',
  );
}
