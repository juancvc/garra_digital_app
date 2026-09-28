/// Pure mirror of the backend ClanPermissions matrix (COMMUNITY_V2_B).
///
/// The backend stays the authority; this only decides which actions the UI
/// offers. Roles: OWNER / ADMIN / MODERATOR / MEMBER.
enum ClanMemberAction {
  makeAdmin,
  makeModerator,
  makeMember,
  remove,
  ban,
  transferOwnership,
}

class ClanAdminPermissions {
  ClanAdminPermissions._();

  static const owner = 'OWNER';
  static const admin = 'ADMIN';
  static const moderator = 'MODERATOR';
  static const member = 'MEMBER';

  static String _n(String? role) => (role ?? '').toUpperCase();

  /// Edit the community and open "Administrar comunidad".
  static bool canManageCommunity(String? actor) {
    final a = _n(actor);
    return a == owner || a == admin;
  }

  static bool canViewBans(String? actor) => canManageCommunity(actor);

  static bool canUnban(String? actor) => canManageCommunity(actor);

  /// Hide posts/comments of the community.
  static bool canModerateContent(String? actor) {
    final a = _n(actor);
    return a == owner || a == admin || a == moderator;
  }

  /// OWNER manages ADMIN/MODERATOR/MEMBER; ADMIN manages MODERATOR/MEMBER.
  static bool canManageMember(String? actor, String? target) {
    final a = _n(actor);
    final t = _n(target);
    if (t == owner) return false;
    if (a == owner) return t == admin || t == moderator || t == member;
    if (a == admin) return t == moderator || t == member;
    return false;
  }

  static bool canBan(String? actor, String? target) =>
      canManageMember(actor, target);

  /// Nobody creates an OWNER through roles; ADMIN never promotes to ADMIN.
  static bool canAssignRole(String? actor, String? target, String newRole) {
    final a = _n(actor);
    final t = _n(target);
    final r = _n(newRole);
    if (t == owner || r == owner) return false;
    if (a == owner) return r == admin || r == moderator || r == member;
    if (a == admin) {
      final targetOk = t == moderator || t == member;
      final newOk = r == moderator || r == member;
      return targetOk && newOk;
    }
    return false;
  }

  static bool canTransferOwnership(String? actor, String? target) =>
      _n(actor) == owner && _n(target) != owner;

  /// Actions [actor] can run on a member whose role is [target].
  static List<ClanMemberAction> actionsFor({
    required String? actor,
    required String? target,
  }) {
    final t = _n(target);
    final actions = <ClanMemberAction>[];
    if (t != admin && canAssignRole(actor, target, admin)) {
      actions.add(ClanMemberAction.makeAdmin);
    }
    if (t != moderator && canAssignRole(actor, target, moderator)) {
      actions.add(ClanMemberAction.makeModerator);
    }
    if (t != member && canAssignRole(actor, target, member)) {
      actions.add(ClanMemberAction.makeMember);
    }
    if (canManageMember(actor, target)) {
      actions.add(ClanMemberAction.remove);
    }
    if (canBan(actor, target)) {
      actions.add(ClanMemberAction.ban);
    }
    if (canTransferOwnership(actor, target)) {
      actions.add(ClanMemberAction.transferOwnership);
    }
    return actions;
  }

  static String label(ClanMemberAction action) {
    switch (action) {
      case ClanMemberAction.makeAdmin:
        return 'Hacer administrador';
      case ClanMemberAction.makeModerator:
        return 'Hacer moderador';
      case ClanMemberAction.makeMember:
        return 'Hacer miembro';
      case ClanMemberAction.remove:
        return 'Expulsar';
      case ClanMemberAction.ban:
        return 'Expulsar y bloquear';
      case ClanMemberAction.transferOwnership:
        return 'Transferir propiedad';
    }
  }

  /// Target role for role-change actions, null otherwise.
  static String? roleFor(ClanMemberAction action) {
    switch (action) {
      case ClanMemberAction.makeAdmin:
        return admin;
      case ClanMemberAction.makeModerator:
        return moderator;
      case ClanMemberAction.makeMember:
        return member;
      case ClanMemberAction.remove:
      case ClanMemberAction.ban:
      case ClanMemberAction.transferOwnership:
        return null;
    }
  }
}
