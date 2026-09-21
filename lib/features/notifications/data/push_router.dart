import 'package:go_router/go_router.dart';

/// Maps push / notification references to app routes. Safe for unknown types.
class PushRouter {
  const PushRouter();

  /// Returns a path to navigate, or `/notifications` as safe fallback.
  /// Returns `/login` when [authenticated] is false.
  String resolveRoute({
    required bool authenticated,
    String? type,
    String? referenceType,
    String? referenceId,
  }) {
    if (!authenticated) return '/login';

    final ref = (referenceType ?? '').toUpperCase();
    final id = referenceId?.trim() ?? '';
    final t = (type ?? '').toUpperCase();

    if (ref == 'POST' && id.isNotEmpty) {
      return '/muro-crema/posts/$id';
    }
    if (ref == 'CLAN' && id.isNotEmpty) {
      return '/clans/$id';
    }
    if (ref == 'MISSION' || t == 'MISSION') {
      return '/missions';
    }
    if (ref == 'REWARD' || t == 'REWARD') {
      return '/rewards/me';
    }
    if (ref == 'REFERRAL' || t == 'REFERRAL') {
      return '/referrals';
    }
    if (ref == 'MATCH' && id.isNotEmpty) {
      return '/matchday/$id/polls';
    }
    if (ref == 'LISTING' || ref == 'MARKETPLACE' || t == 'MARKETPLACE') {
      return '/marketplace';
    }
    return '/notifications';
  }

  void navigate(
    GoRouter router, {
    required bool authenticated,
    String? type,
    String? referenceType,
    String? referenceId,
  }) {
    final path = resolveRoute(
      authenticated: authenticated,
      type: type,
      referenceType: referenceType,
      referenceId: referenceId,
    );
    router.go(path);
  }
}
