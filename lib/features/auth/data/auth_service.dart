import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'auth_user.dart';
import 'register_request.dart';
import 'register_response.dart';

class AuthService {
  AuthService({
    Dio? dio,
    SecureStorageService? storage,
  })  : _dio = dio ?? DioClient.instance,
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
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;

      await _storage.saveToken(token);

      return LoginResult.success(
        user: AuthUser.fromJson(data),
      );
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      return LoginResult.failure(message ?? 'No se pudo iniciar sesión');
    } catch (_) {
      return LoginResult.failure('Ocurrió un error inesperado');
    }
  }

  Future<AuthActionResult<RegisterResponse>> register(
      RegisterRequest request,
      ) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: request.toJson(),
      );

      final data = response.data['data'];

      return AuthActionResult.success(
        message: response.data['message']?.toString() ??
            'Cuenta creada correctamente',
        data: data is Map<String, dynamic>
            ? RegisterResponse.fromJson(data)
            : null,
      );
    } on DioException catch (e) {
      final backendMessage = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      return AuthActionResult.failure(
        _translateRegisterError(
          backendMessage ?? 'No se pudo crear la cuenta',
        ),
      );
    } catch (_) {
      return AuthActionResult.failure('Ocurrió un error inesperado');
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

  Future<void> logout() async {
    await _storage.clearToken();
  }

  static String _translateRegisterError(String message) {
    final normalized = message.toLowerCase();

    if (normalized.contains('email already exists')) {
      return 'Este correo ya está registrado';
    }

    if (normalized.contains('username already exists')) {
      return 'Este nombre de usuario ya está registrado';
    }

    if (normalized.contains('password')) {
      return 'La contraseña no cumple los requisitos';
    }

    return message;
  }
}

class LoginResult {
  const LoginResult({
    required this.success,
    required this.message,
    this.user,
  });

  final bool success;
  final String message;
  final AuthUser? user;

  factory LoginResult.success({
    required AuthUser user,
  }) {
    return LoginResult(
      success: true,
      message: 'Login exitoso',
      user: user,
    );
  }

  factory LoginResult.failure(String message) {
    return LoginResult(
      success: false,
      message: message,
    );
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

  factory AuthActionResult.success({
    required String message,
    T? data,
  }) {
    return AuthActionResult(
      success: true,
      message: message,
      data: data,
    );
  }

  factory AuthActionResult.failure(String message) {
    return AuthActionResult(
      success: false,
      message: message,
    );
  }
}