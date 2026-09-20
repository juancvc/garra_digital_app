/// Compact clan summary for Home / Passport primary clan.
class PrimaryClanSummary {
  const PrimaryClanSummary({
    required this.slug,
    required this.name,
    required this.memberCount,
    this.role,
    this.logoUrl,
  });

  final String slug;
  final String name;
  final int memberCount;
  final String? role;
  final String? logoUrl;

  factory PrimaryClanSummary.fromJson(Map<String, dynamic> json) {
    return PrimaryClanSummary(
      slug: json['slug']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      role: json['role']?.toString(),
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

class ClanModel {
  const ClanModel({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.city,
    this.countryCode,
    required this.visibility,
    required this.joinPolicy,
    required this.status,
    required this.memberCount,
    this.logoUrl,
    this.bannerUrl,
    this.myMembership,
    this.pendingJoinRequest,
    this.createdAt,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? city;
  final String? countryCode;
  final String visibility;
  final String joinPolicy;
  final String status;
  final int memberCount;
  final String? logoUrl;
  final String? bannerUrl;
  final ClanMembershipSummary? myMembership;
  final ClanJoinRequestSummary? pendingJoinRequest;
  final DateTime? createdAt;

  bool get isSuspended => status.toUpperCase() == 'SUSPENDED';
  bool get isArchived => status.toUpperCase() == 'ARCHIVED';
  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isMember =>
      myMembership != null && myMembership!.status.toUpperCase() == 'ACTIVE';
  bool get hasPendingRequest =>
      pendingJoinRequest != null &&
      pendingJoinRequest!.status.toUpperCase() == 'PENDING';
  bool get canManage =>
      isMember &&
      (myMembership!.role.toUpperCase() == 'OWNER' ||
          myMembership!.role.toUpperCase() == 'ADMIN');
  bool get isOwner =>
      isMember && myMembership!.role.toUpperCase() == 'OWNER';

  String get locationLabel {
    final cityTrim = city?.trim();
    final countryTrim = countryCode?.trim();
    if ((cityTrim == null || cityTrim.isEmpty) &&
        (countryTrim == null || countryTrim.isEmpty)) {
      return '';
    }
    if (cityTrim != null &&
        cityTrim.isNotEmpty &&
        countryTrim != null &&
        countryTrim.isNotEmpty) {
      return '$cityTrim · $countryTrim';
    }
    return cityTrim ?? countryTrim ?? '';
  }

  factory ClanModel.fromJson(Map<String, dynamic> json) {
    return ClanModel(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      city: json['city'] as String?,
      countryCode: json['countryCode'] as String?,
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
      joinPolicy: json['joinPolicy']?.toString() ?? 'OPEN',
      status: json['status']?.toString() ?? 'ACTIVE',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      myMembership: json['myMembership'] == null
          ? null
          : ClanMembershipSummary.fromJson(
              Map<String, dynamic>.from(json['myMembership'] as Map),
            ),
      pendingJoinRequest: json['pendingJoinRequest'] == null
          ? null
          : ClanJoinRequestSummary.fromJson(
              Map<String, dynamic>.from(json['pendingJoinRequest'] as Map),
            ),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class ClanMembershipSummary {
  const ClanMembershipSummary({
    required this.role,
    required this.status,
    this.isPrimary = false,
    this.joinedAt,
  });

  final String role;
  final String status;
  final bool isPrimary;
  final DateTime? joinedAt;

  factory ClanMembershipSummary.fromJson(Map<String, dynamic> json) {
    return ClanMembershipSummary(
      role: json['role']?.toString() ?? 'MEMBER',
      status: json['status']?.toString() ?? 'ACTIVE',
      isPrimary: json['isPrimary'] as bool? ?? false,
      joinedAt: ClanModel._parseDateTime(json['joinedAt']),
    );
  }
}

/// Membership row returned by GET /clans/me (clan + role).
class MyClanMembership {
  const MyClanMembership({
    required this.clan,
    required this.role,
    required this.status,
    this.isPrimary = false,
    this.joinedAt,
  });

  final ClanModel clan;
  final String role;
  final String status;
  final bool isPrimary;
  final DateTime? joinedAt;

  factory MyClanMembership.fromJson(Map<String, dynamic> json) {
    final clanJson = json['clan'] is Map
        ? Map<String, dynamic>.from(json['clan'] as Map)
        : Map<String, dynamic>.from(json);
    final nestedMembership = clanJson['myMembership'] is Map
        ? Map<String, dynamic>.from(clanJson['myMembership'] as Map)
        : const <String, dynamic>{};
    return MyClanMembership(
      clan: ClanModel.fromJson(clanJson),
      role: (json['role'] ?? nestedMembership['role'])?.toString() ?? 'MEMBER',
      status:
          (json['status'] ?? nestedMembership['status'])?.toString() ?? 'ACTIVE',
      isPrimary: json['isPrimary'] as bool? ??
          nestedMembership['isPrimary'] as bool? ??
          false,
      joinedAt: ClanModel._parseDateTime(
        json['joinedAt'] ?? nestedMembership['joinedAt'],
      ),
    );
  }
}

class ClanJoinRequestSummary {
  const ClanJoinRequestSummary({
    required this.id,
    required this.status,
    this.message,
    this.createdAt,
  });

  final String id;
  final String status;
  final String? message;
  final DateTime? createdAt;

  factory ClanJoinRequestSummary.fromJson(Map<String, dynamic> json) {
    return ClanJoinRequestSummary(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      message: json['message'] as String?,
      createdAt: ClanModel._parseDateTime(json['createdAt']),
    );
  }
}

class ClanJoinRequestModel {
  const ClanJoinRequestModel({
    required this.id,
    required this.status,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.message,
    this.createdAt,
  });

  final String id;
  final String status;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? message;
  final DateTime? createdAt;

  factory ClanJoinRequestModel.fromJson(Map<String, dynamic> json) {
    final fan = json['fan'] is Map
        ? Map<String, dynamic>.from(json['fan'] as Map)
        : const <String, dynamic>{};
    return ClanJoinRequestModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      username: (json['username'] ?? fan['username'])?.toString() ?? '',
      displayName:
          (json['displayName'] ?? fan['displayName'])?.toString() ?? '',
      avatarUrl: (json['avatarUrl'] ?? fan['avatarUrl']) as String?,
      message: json['message'] as String?,
      createdAt: ClanModel._parseDateTime(json['createdAt']),
    );
  }
}

class ClanMemberModel {
  const ClanMemberModel({
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    this.joinedAt,
  });

  final String username;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final DateTime? joinedAt;

  factory ClanMemberModel.fromJson(Map<String, dynamic> json) {
    return ClanMemberModel(
      username: json['username']?.toString() ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role']?.toString() ??
          json['clanRole']?.toString() ??
          'MEMBER',
      joinedAt: ClanModel._parseDateTime(json['joinedAt']),
    );
  }
}

class ClanInvitationModel {
  const ClanInvitationModel({
    required this.id,
    required this.status,
    required this.clan,
    this.invitedByUsername,
    this.invitedByDisplayName,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String status;
  final ClanModel clan;
  final String? invitedByUsername;
  final String? invitedByDisplayName;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  bool get isPending => status.toUpperCase() == 'PENDING';

  factory ClanInvitationModel.fromJson(Map<String, dynamic> json) {
    final clanJson = json['clan'] is Map
        ? Map<String, dynamic>.from(json['clan'] as Map)
        : <String, dynamic>{
            'slug': json['clanSlug'],
            'name': json['clanName'],
            'memberCount': json['memberCount'] ?? 0,
            'joinPolicy': json['joinPolicy'] ?? 'INVITE_ONLY',
            'visibility': json['visibility'] ?? 'PRIVATE',
            'status': json['clanStatus'] ?? 'ACTIVE',
          };
    final invitedBy = json['invitedBy'] is Map
        ? Map<String, dynamic>.from(json['invitedBy'] as Map)
        : const <String, dynamic>{};
    return ClanInvitationModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      clan: ClanModel.fromJson(clanJson),
      invitedByUsername:
          (json['invitedByUsername'] ?? invitedBy['username'])?.toString(),
      invitedByDisplayName: (json['invitedByDisplayName'] ??
              invitedBy['displayName'])
          ?.toString(),
      createdAt: ClanModel._parseDateTime(json['createdAt']),
      expiresAt: ClanModel._parseDateTime(json['expiresAt']),
    );
  }
}

class ClanPage<T> {
  const ClanPage({
    required this.items,
    this.nextCursor,
    this.hasNext = false,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasNext;
}

class CreateClanRequest {
  const CreateClanRequest({
    required this.name,
    required this.slug,
    this.description,
    this.city,
    this.countryCode,
    this.visibility = 'PUBLIC',
    this.joinPolicy = 'OPEN',
  });

  final String name;
  final String slug;
  final String? description;
  final String? city;
  final String? countryCode;
  final String visibility;
  final String joinPolicy;

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        if (description != null) 'description': description,
        if (city != null) 'city': city,
        if (countryCode != null) 'countryCode': countryCode,
        'visibility': visibility,
        'joinPolicy': joinPolicy,
      };
}

class UpdateClanRequest {
  const UpdateClanRequest({
    this.name,
    this.description,
    this.city,
    this.countryCode,
    this.visibility,
    this.joinPolicy,
    this.logoUrl,
    this.bannerUrl,
  });

  final String? name;
  final String? description;
  final String? city;
  final String? countryCode;
  final String? visibility;
  final String? joinPolicy;
  final String? logoUrl;
  final String? bannerUrl;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (city != null) 'city': city,
        if (countryCode != null) 'countryCode': countryCode,
        if (visibility != null) 'visibility': visibility,
        if (joinPolicy != null) 'joinPolicy': joinPolicy,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (bannerUrl != null) 'bannerUrl': bannerUrl,
      };
}

class ClanJoinPolicyLabels {
  ClanJoinPolicyLabels._();

  static String label(String joinPolicy) {
    switch (joinPolicy.toUpperCase()) {
      case 'REQUEST':
        return 'Solicitar ingreso';
      case 'INVITE_ONLY':
        return 'Solo por invitación';
      case 'OPEN':
      default:
        return 'Unirme';
    }
  }

  static String indicator(String joinPolicy) {
    switch (joinPolicy.toUpperCase()) {
      case 'REQUEST':
        return 'Con solicitud';
      case 'INVITE_ONLY':
        return 'Solo invitación';
      case 'OPEN':
      default:
        return 'Abierto';
    }
  }
}

class ClanRoleLabels {
  ClanRoleLabels._();

  static String label(String? role) {
    switch ((role ?? '').toUpperCase()) {
      case 'OWNER':
        return 'Propietario';
      case 'ADMIN':
        return 'Admin';
      case 'MODERATOR':
        return 'Moderador';
      case 'MEMBER':
        return 'Miembro';
      default:
        return role ?? '';
    }
  }
}
