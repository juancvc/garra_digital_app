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
    // Invitation deep link — never treat invitation UUID as a clan slug.
    if (ref == 'CLAN_INVITATION') {
      return '/clans/invitations';
    }
    // Generic CLAN references carry clan UUID, but routes expect slug.
    // Fall back to communities hub rather than `/clans/{uuid}`.
    if (ref == 'CLAN') {
      return '/clans';
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
    if (ref == 'CREMA_BUSINESS_APPLICATION') {
      return '/ruta-templo/mi-negocio';
    }
    if (ref == 'SOLIDARITY' || ref == 'SOLIDARITY_CAMPAIGN') {
      return id.isNotEmpty ? '/solidaria/$id' : '/solidaria';
    }
    if (ref == 'BUSINESS_OFFER') {
      return id.isNotEmpty ? '/ruta-templo?offerId=$id' : '/ruta-templo';
    }
    if (ref == 'FAN_USER' && id.isNotEmpty) {
      return '/comunidad/u/$id';
    }
    if (ref == 'CREMA_POINT' || ref == 'FOLLOWED_BUSINESS') {
      return '/ruta-templo';
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
