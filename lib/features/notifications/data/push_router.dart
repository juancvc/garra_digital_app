import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    if (ref.startsWith('POST_COMMENT:') && id.isNotEmpty) {
      final postId = (referenceType ?? '').substring('POST_COMMENT:'.length);
      if (postId.isNotEmpty) return '/muro-crema/posts/$postId?commentId=$id';
    }
    if (ref.startsWith('COMMUNITY_CHAT:') && id.isNotEmpty) {
      final slug = (referenceType ?? '').substring('COMMUNITY_CHAT:'.length);
      if (slug.isNotEmpty) return '/clans/${Uri.encodeComponent(slug)}/chat?messageId=$id';
    }
    // PRODUCT-08C: direct replies in Football Chat (backend 08B: FOOTBALL_CHAT:GENERAL |
    // FOOTBALL_CHAT:MATCH:{matchId}; referenceId = reply messageId). Bare FOOTBALL_CHAT = GENERAL.
    if (ref == 'FOOTBALL_CHAT' || ref.startsWith('FOOTBALL_CHAT:')) {
      final footballChat = footballChatRoute(ref, id);
      if (footballChat != null) return footballChat;
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
    if (ref == 'CHAT_CONVERSATION') {
      return id.isNotEmpty ? '/chat/$id' : '/notifications';
    }
    return '/notifications';
  }

  /// `/comunidad` (Comunidad Crema = GENERAL room) or `/centro-garra/chat-futbolero?partido=` (MATCH room),
  /// with `messageId` so the room can scroll to the reply. Invalid match ids → null (safe fallback).
  static String? footballChatRoute(String upperRef, String messageId) {
    final query = messageId.isEmpty ? '' : 'messageId=${Uri.encodeQueryComponent(messageId)}';
    if (upperRef == 'FOOTBALL_CHAT' || upperRef == 'FOOTBALL_CHAT:GENERAL') {
      return query.isEmpty ? '/comunidad' : '/comunidad?$query';
    }
    const matchPrefix = 'FOOTBALL_CHAT:MATCH:';
    if (upperRef.startsWith(matchPrefix)) {
      final raw = upperRef.substring(matchPrefix.length);
      final matchId = int.tryParse(raw);
      if (matchId == null || matchId <= 0 || raw != '$matchId') return null;
      return '/centro-garra/chat-futbolero?partido=$matchId${query.isEmpty ? '' : '&$query'}';
    }
    return null;
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

/// PRODUCT-08C: a push open (tap, `getInitialMessage`) navigates at most once per notification, also across
/// app restarts (Android can redeliver the launch message when the app is reopened from recents).
class PushOpenDedupe {
  PushOpenDedupe({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  static const prefsKey = 'garra.push.handled_open_ids';
  static const maxRemembered = 30;

  final Future<SharedPreferences> Function() _prefs;
  final Set<String> _session = {};

  /// True when [notificationId] was not handled before (and marks it). Empty ids are always allowed.
  Future<bool> claim(String? notificationId) async {
    final id = notificationId?.trim() ?? '';
    if (id.isEmpty) return true;
    if (!_session.add(id)) return false;
    try {
      final prefs = await _prefs();
      final seen = prefs.getStringList(prefsKey) ?? const <String>[];
      if (seen.contains(id)) return false;
      final next = [...seen, id];
      await prefs.setStringList(
        prefsKey,
        next.length > maxRemembered ? next.sublist(next.length - maxRemembered) : next,
      );
    } catch (_) {
      // Storage failure: the in-memory guard still prevents duplicates in this session.
    }
    return true;
  }
}
