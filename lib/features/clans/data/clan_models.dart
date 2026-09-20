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
    this.currentYearPollaPoints,
    this.currentYearRank,
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
  final int? currentYearPollaPoints;
  final int? currentYearRank;

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
      currentYearPollaPoints:
          (json['currentYearPollaPoints'] as num?)?.toInt() ??
              (json['currentYearPoints'] as num?)?.toInt(),
      currentYearRank: (json['currentYearRank'] as num?)?.toInt(),
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

/// Create body for clan tribuna posts (no matchId).
class CreateClanPostRequest {
  const CreateClanPostRequest({
    required this.content,
    this.imageUrl,
    this.locationTag = 'HOME',
  });

  final String content;
  final String? imageUrl;
  final String locationTag;

  Map<String, dynamic> toJson() => {
        'content': content,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'locationTag': locationTag,
      };
}

class ClanPollaMatchModel {
  const ClanPollaMatchModel({
    this.match,
    required this.state,
    required this.memberCount,
    required this.participantCount,
    this.participationPercent,
    this.myPrediction,
    this.memberPredictions = const [],
    this.scoredSummary,
    this.year,
    this.predictionsRevealed = false,
  });

  final ClanPollaMatchInfo? match;
  final String state;
  final int memberCount;
  final int participantCount;
  final double? participationPercent;
  final ClanPollaPrediction? myPrediction;
  final List<ClanPollaMemberPrediction> memberPredictions;
  final ClanPollaScoredSummary? scoredSummary;
  final int? year;
  final bool predictionsRevealed;

  bool get hasMatch => match != null && match!.id.isNotEmpty;
  bool get isPrelock =>
      state == 'OPEN' || state == 'SUBMITTED' || state == 'NOT_OPEN';
  bool get isLocked => state == 'LOCKED';
  bool get isScored => state == 'SCORED';
  bool get isNoMatch =>
      state == 'NO_MATCH' || !hasMatch;

  factory ClanPollaMatchModel.fromJson(Map<String, dynamic> json) {
    final state = (json['state'] ?? json['pollaState'])?.toString() ?? 'NO_MATCH';
    final revealed = json['predictionsRevealed'] as bool? ??
        (state == 'LOCKED' || state == 'SCORED');
    final membersRaw = json['memberPredictions'] ?? json['predictions'];
    return ClanPollaMatchModel(
      match: json['match'] is Map
          ? ClanPollaMatchInfo.fromJson(
              Map<String, dynamic>.from(json['match'] as Map),
            )
          : null,
      state: state,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      participationPercent:
          (json['participationPercent'] as num?)?.toDouble(),
      myPrediction: json['myPrediction'] is Map
          ? ClanPollaPrediction.fromJson(
              Map<String, dynamic>.from(json['myPrediction'] as Map),
            )
          : null,
      memberPredictions: revealed && membersRaw is List
          ? membersRaw
              .map(
                (e) => ClanPollaMemberPrediction.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
      scoredSummary: json['scoredSummary'] is Map
          ? ClanPollaScoredSummary.fromJson(
              Map<String, dynamic>.from(json['scoredSummary'] as Map),
            )
          : null,
      year: (json['year'] as num?)?.toInt(),
      predictionsRevealed: revealed,
    );
  }
}

class ClanPollaMatchInfo {
  const ClanPollaMatchInfo({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    this.matchDateTime,
    this.stadium,
    this.competition,
    this.homeScore,
    this.awayScore,
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime? matchDateTime;
  final String? stadium;
  final String? competition;
  final int? homeScore;
  final int? awayScore;

  factory ClanPollaMatchInfo.fromJson(Map<String, dynamic> json) {
    return ClanPollaMatchInfo(
      id: json['id']?.toString() ?? '',
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      matchDateTime: ClanModel._parseDateTime(json['matchDateTime']),
      stadium: json['stadium'] as String?,
      competition: json['competition'] as String?,
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
    );
  }
}

class ClanPollaPrediction {
  const ClanPollaPrediction({
    this.homeScore,
    this.awayScore,
    this.firstScorer,
    this.status,
    this.pointsEarned,
  });

  final int? homeScore;
  final int? awayScore;
  final String? firstScorer;
  final String? status;
  final int? pointsEarned;

  bool get hasScores => homeScore != null && awayScore != null;

  String get scoreLabel {
    if (!hasScores) return 'Sin predicción';
    return '$homeScore - $awayScore';
  }

  factory ClanPollaPrediction.fromJson(Map<String, dynamic> json) {
    return ClanPollaPrediction(
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
      firstScorer: json['firstScorer'] as String?,
      status: json['status']?.toString(),
      pointsEarned: (json['pointsEarned'] as num?)?.toInt(),
    );
  }
}

class ClanPollaMemberPrediction {
  const ClanPollaMemberPrediction({
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.homeScore,
    this.awayScore,
    this.firstScorer,
    this.pointsEarned,
    this.rank,
  });

  final String username;
  final String displayName;
  final String? avatarUrl;
  final int? homeScore;
  final int? awayScore;
  final String? firstScorer;
  final int? pointsEarned;
  final int? rank;

  String get scoreLabel {
    if (homeScore == null || awayScore == null) return '—';
    return '$homeScore - $awayScore';
  }

  factory ClanPollaMemberPrediction.fromJson(Map<String, dynamic> json) {
    final fan = json['fan'] is Map
        ? Map<String, dynamic>.from(json['fan'] as Map)
        : const <String, dynamic>{};
    return ClanPollaMemberPrediction(
      username: (json['username'] ?? fan['username'])?.toString() ?? '',
      displayName:
          (json['displayName'] ?? fan['displayName'])?.toString() ?? '',
      avatarUrl: (json['avatarUrl'] ?? fan['avatarUrl']) as String?,
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
      firstScorer: json['firstScorer'] as String?,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt(),
      rank: (json['rank'] as num?)?.toInt(),
    );
  }
}

class ClanPollaScoredSummary {
  const ClanPollaScoredSummary({
    this.totalClanPoints = 0,
    this.participants = 0,
    this.averagePoints,
  });

  final int totalClanPoints;
  final int participants;
  final double? averagePoints;

  factory ClanPollaScoredSummary.fromJson(Map<String, dynamic> json) {
    return ClanPollaScoredSummary(
      totalClanPoints: (json['totalClanPoints'] as num?)?.toInt() ??
          (json['totalPoints'] as num?)?.toInt() ??
          0,
      participants: (json['participants'] as num?)?.toInt() ??
          (json['participantCount'] as num?)?.toInt() ??
          0,
      averagePoints: (json['averagePoints'] as num?)?.toDouble(),
    );
  }
}

class ClanMemberRankingEntry {
  const ClanMemberRankingEntry({
    required this.rank,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.predictionPoints,
    this.predictionsScored,
  });

  final int rank;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int predictionPoints;
  final int? predictionsScored;

  factory ClanMemberRankingEntry.fromJson(Map<String, dynamic> json) {
    final fan = json['fan'] is Map
        ? Map<String, dynamic>.from(json['fan'] as Map)
        : const <String, dynamic>{};
    return ClanMemberRankingEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? fan['username'])?.toString() ?? '',
      displayName:
          (json['displayName'] ?? fan['displayName'])?.toString() ?? '',
      avatarUrl: (json['avatarUrl'] ?? fan['avatarUrl']) as String?,
      predictionPoints: (json['predictionPoints'] as num?)?.toInt() ??
          (json['points'] as num?)?.toInt() ??
          (json['totalPoints'] as num?)?.toInt() ??
          0,
      predictionsScored: (json['predictionsScored'] as num?)?.toInt(),
    );
  }
}

class ClanGlobalRankingEntry {
  const ClanGlobalRankingEntry({
    required this.rank,
    required this.slug,
    required this.name,
    required this.totalPoints,
    this.memberCount,
    this.logoUrl,
    this.scoredPredictions,
    this.isPrimary = false,
  });

  final int rank;
  final String slug;
  final String name;
  final int totalPoints;
  final int? memberCount;
  final String? logoUrl;
  final int? scoredPredictions;
  final bool isPrimary;

  factory ClanGlobalRankingEntry.fromJson(Map<String, dynamic> json) {
    final clan = json['clan'] is Map
        ? Map<String, dynamic>.from(json['clan'] as Map)
        : json;
    return ClanGlobalRankingEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] ?? clan['slug'])?.toString() ?? '',
      name: (json['name'] ?? clan['name']) as String? ?? '',
      totalPoints: (json['totalPoints'] as num?)?.toInt() ??
          (json['pollaPoints'] as num?)?.toInt() ??
          0,
      memberCount: (json['memberCount'] as num?)?.toInt() ??
          (clan['memberCount'] as num?)?.toInt(),
      logoUrl: (json['logoUrl'] ?? clan['logoUrl']) as String?,
      scoredPredictions: (json['scoredPredictions'] as num?)?.toInt(),
      isPrimary: json['isPrimary'] as bool? ??
          json['primary'] as bool? ??
          false,
    );
  }
}
