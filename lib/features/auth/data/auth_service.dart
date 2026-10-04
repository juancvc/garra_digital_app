import 'package:dio/dio.dart';

import '../../../core/auth/session_events.dart';
import '../../../core/network/dio_client.dart';
import '../../notifications/data/push_device_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'auth_flow_models.dart';
import 'auth_user.dart';
import 'register_request.dart';
import 'register_response.dart';
import 'google_auth_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService({Dio? dio, SecureStorageService? storage})
    : _dio = dio ?? DioClient.instance,
      _storage = storage ?? SecureStorageService();

  final Dio _dio;
  final SecureStorageService _storage;

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;

      await _storage.saveToken(token);

      return LoginResult.success(user: AuthUser.fromJson(data));
    } on DioException catch (e) {
      final failure = authFailureFromDio<void>(
        e,
        fallback: 'No se pudo iniciar sesi\u00f3n',
      );
      if (failure.kind == AuthFailureKind.emailVerificationRequired) {
        return LoginResult.verificationRequired();
      }
      if (failure.kind == AuthFailureKind.rateLimited ||
          failure.kind == AuthFailureKind.network ||
          failure.kind == AuthFailureKind.server) {
        return LoginResult.failure(failure.message);
      }
      final message = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;
      return LoginResult.failure(message ?? 'No se pudo iniciar sesi\u00f3n');
    } catch (_) {
      return LoginResult.failure('Ocurrió un error inesperado');
    }
  }

  Future<AuthFlowResult<RegisterOutcome>> register(
    RegisterRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: request.toJson(),
      );

      final data = response.data['data'];
      final parsed = data is Map<String, dynamic>
          ? RegisterResponse.fromJson(data)
          : null;

      return AuthFlowResult.success(
        message:
            response.data['message']?.toString() ??
            'Cuenta creada correctamente',
        data: RegisterOutcome(
          verificationRequired: parsed?.verificationRequired ?? false,
          email: (parsed?.email.isNotEmpty ?? false)
              ? parsed!.email
              : request.email,
          resendAvailableInSeconds: parsed?.resendAvailableInSeconds ?? 60,
          codeExpiresInSeconds: parsed?.codeExpiresInSeconds ?? 600,
        ),
      );
    } on DioException catch (e) {
      return authFailureFromDio(e, fallback: 'No se pudo crear la cuenta');
    } catch (_) {
      return AuthFlowResult.failure(
        AuthFailureKind.unknown,
        authUnknownMessage,
      );
    }
  }

  /// POST /auth/email-verification/verify. On success the server starts the
  /// session; it is persisted exactly like a login.
  Future<AuthFlowResult<AuthUser>> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/email-verification/verify',
        data: {'email': email.trim().toLowerCase(), 'code': code.trim()},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await _storage.saveToken(data['token'] as String);
      final refresh = data['refreshToken']?.toString();
      if (refresh != null && refresh.isNotEmpty) {
        await _storage.saveRefreshToken(refresh);
      }
      return AuthFlowResult.success(data: AuthUser.fromJson(data));
    } on DioException catch (e) {
      return authFailureFromDio(e, fallback: authInvalidCodeMessage);
    } catch (_) {
      return AuthFlowResult.failure(
        AuthFailureKind.unknown,
        authUnknownMessage,
      );
    }
  }

  Future<AuthFlowResult<ResendAck>> resendVerification(String email) {
    return _requestCode('/auth/email-verification/resend', email);
  }

  Future<AuthFlowResult<ResendAck>> forgotPassword(String email) {
    return _requestCode('/auth/password/forgot', email);
  }

  Future<AuthFlowResult<ResendAck>> _requestCode(
    String path,
    String email,
  ) async {
    try {
      final response = await _dio.post(
        path,
        data: {'email': email.trim().toLowerCase()},
      );
      final data = response.data['data'];
      final map = data is Map ? data : const {};
      return AuthFlowResult.success(
        message: authNeutralAcceptedMessage,
        data: ResendAck(
          resendAvailableInSeconds: resendSecondsFrom(
            map['resendAvailableInSeconds'],
          ),
          codeExpiresInSeconds: codeSecondsFrom(map['codeExpiresInSeconds']),
        ),
      );
    } on DioException catch (e) {
      return authFailureFromDio(e, fallback: authServerMessage);
    } catch (_) {
      return AuthFlowResult.failure(
        AuthFailureKind.unknown,
        authUnknownMessage,
      );
    }
  }

  /// POST /auth/password/reset. The password is sent once and never kept for
  /// a retry; no session is started (the user logs in afterwards).
  Future<AuthFlowResult<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/auth/password/reset',
        data: {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'newPassword': newPassword,
        },
      );
      return AuthFlowResult.success();
    } on DioException catch (e) {
      return authFailureFromDio(e, fallback: authInvalidCodeMessage);
    } catch (_) {
      return AuthFlowResult.failure(
        AuthFailureKind.unknown,
        authUnknownMessage,
      );
    }
  }

  Future<AuthUser?> me() async {
    try {
      final response = await _dio.get('/auth/me');
      final data = response.data['data'] as Map<String, dynamic>;

      return AuthUser.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Ends the session completely. Order matters: the server calls need the
  /// access token, so they run (best effort, bounded) BEFORE local cleanup.
  /// 1) the device stops receiving this user's pushes, 2) the refresh token is
  /// revoked server-side, 3) both tokens are removed locally (a leftover
  /// refresh token would let a late 401 silently sign the user back in),
  /// 4) [SessionEvents] resets user-scoped providers.
  Future<void> logout() async {
    const bound = Duration(seconds: 4);
    try {
      await PushDeviceService(dio: _dio).deactivateCurrent().timeout(bound);
    } catch (_) {}
    try {
      final refresh = await _storage.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _dio
            .post('/auth/logout', data: {'refreshToken': refresh})
            .timeout(bound);
      }
    } catch (_) {}
    try {
      await GoogleAuthService().signOut();
    } catch (_) {}
    await _storage.clearSessionTokens();
    try {
      await _storage.clearDevicePushKeys();
    } catch (_) {}
    SessionEvents.emit(SessionEventKind.ended);
  }

  Future<LoginResult> loginWithGoogle() async {
    try {
      final firebaseIdToken = await GoogleAuthService().signInWithGoogle();

      if (firebaseIdToken == null) {
        return LoginResult.failure('Inicio con Google cancelado');
      }

      final response = await _dio.post(
        '/auth/google',
        data: {'idToken': firebaseIdToken},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;

      await _storage.saveToken(token);

      return LoginResult.success(user: AuthUser.fromJson(data));
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      return LoginResult.failure(message ?? 'No se pudo iniciar con Google');
    } catch (e, stack) {
      debugPrint('❌ GOOGLE LOGIN ERROR: $e');
      debugPrint('❌ GOOGLE LOGIN STACK: $stack');

      return LoginResult.failure('Ocurrió un error con Google Login: $e');
    }
  }

  /// GARRA39.1: completes the Garra profile (membership). The backend is the
  /// authority: it rejects the call unless both acceptances are true.
  Future<AuthActionResult<AuthUser>> completeProfile({
    required String username,
    required String favoriteStand,
    String? fullName,
    String? favoritePlayer,
    required bool cremaDeclarationAccepted,
    required bool communityGuidelinesAccepted,
  }) async {
    try {
      final response = await _dio.patch(
        '/auth/complete-profile',
        data: {
          'username': username.trim(),
          'favoriteStand': favoriteStand,
          if (fullName != null && fullName.trim().isNotEmpty)
            'fullName': fullName.trim(),
          if (favoritePlayer != null && favoritePlayer.trim().isNotEmpty)
            'favoritePlayer': favoritePlayer.trim(),
          'cremaDeclarationAccepted': cremaDeclarationAccepted,
          'communityGuidelinesAccepted': communityGuidelinesAccepted,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;

      // The completed profile comes with a fresh JWT.
      await _storage.saveToken(token);

      return AuthActionResult.success(
        message: 'Perfil completado',
        data: AuthUser.fromJson(data),
      );
    } on DioException catch (e) {
      final failure = authFailureFromDio<void>(
        e,
        fallback: 'No se pudo completar el perfil',
      );
      if (failure.kind == AuthFailureKind.network ||
          failure.kind == AuthFailureKind.rateLimited ||
          failure.kind == AuthFailureKind.server) {
        return AuthActionResult.failure(failure.message);
      }
      final message = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;
      if ((message ?? '').toLowerCase().contains('username already exists')) {
        return AuthActionResult.failure(authUsernameTakenMessage);
      }
      return AuthActionResult.failure(
        message ?? 'No se pudo completar el perfil',
      );
    } catch (_) {
      return AuthActionResult.failure('Error inesperado');
    }
  }
}

class LoginResult {
  const LoginResult({
    required this.success,
    required this.message,
    this.user,
    this.requiresEmailVerification = false,
  });

  final bool success;
  final String message;
  final AuthUser? user;

  /// Typed (HTTP 403 + errors.code): the password was right but the e-mail is
  /// not verified yet. The UI sends the user to the code screen.
  final bool requiresEmailVerification;

  factory LoginResult.verificationRequired() {
    return const LoginResult(
      success: false,
      message: 'Debes verificar tu correo para continuar.',
      requiresEmailVerification: true,
    );
  }

  factory LoginResult.success({required AuthUser user}) {
    return LoginResult(success: true, message: 'Login exitoso', user: user);
  }

  factory LoginResult.failure(String message) {
    return LoginResult(success: false, message: message);
  }
}

class AuthActionResult<T> {
  const AuthActionResult({
    required this.success,
    required this.message,
    this.data,
  });

  final bool success;
  final String message;
  final T? data;

  factory AuthActionResult.success({required String message, T? data}) {
    return AuthActionResult(success: true, message: message, data: data);
  }

  factory AuthActionResult.failure(String message) {
    return AuthActionResult(success: false, message: message);
  }
}
