import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';
import '../../data/auth_user.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final currentUserProvider = FutureProvider<AuthUser?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.me();
});