import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/community_link_config.dart';
import '../../../notifications/data/push_session_coordinator.dart';
import '../../data/auth_service.dart';
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

/// GARRA39.1 single post-auth decision, shared by Google, e-mail login,
/// e-mail verification, the Garra profile and a relaunch with a session:
/// membership pending -> /complete-profile; onboarding pending -> /onboarding;
/// otherwise /home. (Not authenticated and e-mail verification are decided
/// earlier: the login/entry screens and the typed EMAIL_VERIFICATION_REQUIRED.)
/// Overridable in tests.
final postAuthDestinationProvider = Provider<PostVerifyDestination>(
  (ref) => defaultPostVerifyDestination,
);

/// Kept for the GARRA39 call sites/tests: the very same provider.
final postVerifyDestinationProvider = postAuthDestinationProvider;

/// Applies a deep-link `next` only when the decision is the plain Home.
Future<String> postAuthRoute(
  PostVerifyDestination destinationFor,
  AuthUser user, {
  String? next,
}) async {
  final destination = await destinationFor(user);
  if (destination == '/home') {
    return CommunityLinkConfig.safeDestination(next) ?? '/home';
  }
  return destination;
}

/// Relaunch with a stored session: ask the server who we are so a member whose
/// Garra profile is still pending never lands on a Home that would answer 403.
Future<String> resolveSessionDestination() async {
  final user = await AuthService().me();
  if (user == null) return '/home';
  return defaultPostVerifyDestination(user);
}

Future<String> defaultPostVerifyDestination(AuthUser user) async {
  if (user.status == 'PENDING_PROFILE' && !user.isAdmin) {
    return '/complete-profile';
  }
  await pushSessionCoordinator.afterAuthenticated();
  // Same rule as CompleteProfilePage (GARRA38): the skippable social
  // onboarding once; any failure just goes to Home.
  try {
    final prefs = await RetentionService().getInterests();
    if (!prefs.onboardingCompleted) return '/onboarding';
  } catch (_) {}
  return '/home';
}
