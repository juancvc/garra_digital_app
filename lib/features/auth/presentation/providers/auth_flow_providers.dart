import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifications/data/push_session_coordinator.dart';
import '../../../retention/data/retention_service.dart';
import '../../data/auth_user.dart';

/// Arguments of /verify-email. Carried in the route `extra` (memory only): the
/// e-mail is never persisted and the password never leaves the register form.
class VerifyEmailArgs {
  const VerifyEmailArgs({
    required this.email,
    this.resendAvailableInSeconds = 60,
    this.fromLogin = false,
  });

  final String email;
  final int resendAvailableInSeconds;
  final bool fromLogin;
}

/// Arguments of /reset-password.
class ResetPasswordArgs {
  const ResetPasswordArgs({
    required this.email,
    this.resendAvailableInSeconds = 60,
  });

  final String email;
  final int resendAvailableInSeconds;
}

typedef PostVerifyDestination = Future<String> Function(AuthUser user);

/// Where a freshly verified account lands. Overridable in tests.
final postVerifyDestinationProvider = Provider<PostVerifyDestination>(
  (ref) => defaultPostVerifyDestination,
);

Future<String> defaultPostVerifyDestination(AuthUser user) async {
  if (user.status == 'PENDING_PROFILE') return '/complete-profile';
  await pushSessionCoordinator.afterAuthenticated();
  // Same rule as CompleteProfilePage (GARRA38): the skippable social
  // onboarding once; any failure just goes to Home.
  try {
    final prefs = await RetentionService().getInterests();
    if (!prefs.onboardingCompleted) return '/onboarding';
  } catch (_) {}
  return '/home';
}
