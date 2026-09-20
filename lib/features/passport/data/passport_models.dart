class PassportModel {
  const PassportModel({
    required this.identity,
    required this.level,
    required this.stats,
    required this.globalRank,
    required this.profileVisibility,
    required this.viewerIsOwner,
    this.primaryClan,
    this.currentYearSummary,
  });

  final PassportIdentity identity;
  final PassportLevel level;
  final PassportStats stats;
  final int? globalRank;
  final String profileVisibility;
  final bool viewerIsOwner;
  final PassportClanSummary? primaryClan;
  final PassportCurrentYearSummary? currentYearSummary;

  factory PassportModel.fromJson(Map<String, dynamic> json) {
    return PassportModel(
      identity: PassportIdentity.fromJson(
        Map<String, dynamic>.from(json['identity'] as Map),
      ),
      level: PassportLevel.fromJson(
        Map<String, dynamic>.from(json['level'] as Map),
      ),
      stats: PassportStats.fromJson(
        Map<String, dynamic>.from(json['stats'] as Map),
      ),
      globalRank: (json['globalRank'] as num?)?.toInt(),
      profileVisibility: json['profileVisibility'] as String? ?? 'PUBLIC',
      viewerIsOwner: json['viewerIsOwner'] as bool? ?? false,
      primaryClan: json['primaryClan'] == null
          ? null
          : PassportClanSummary.fromJson(
              Map<String, dynamic>.from(json['primaryClan'] as Map),
            ),
      currentYearSummary: json['currentYearSummary'] == null
          ? null
          : PassportCurrentYearSummary.fromJson(
              Map<String, dynamic>.from(json['currentYearSummary'] as Map),
            ),
    );
  }
}

/// Compact year summary nested on Passport — bounded query.
class PassportCurrentYearSummary {
  const PassportCurrentYearSummary({
    required this.year,
    this.pointsEarned = 0,
    this.matchdaysParticipated = 0,
    this.predictionsSubmitted = 0,
    this.missionsCompleted = 0,
  });

  final int year;
  final int pointsEarned;
  final int matchdaysParticipated;
  final int predictionsSubmitted;
  final int missionsCompleted;

  bool get hasActivity =>
      pointsEarned > 0 ||
      matchdaysParticipated > 0 ||
      predictionsSubmitted > 0 ||
      missionsCompleted > 0;

  factory PassportCurrentYearSummary.fromJson(Map<String, dynamic> json) {
    return PassportCurrentYearSummary(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      matchdaysParticipated:
          (json['matchdaysParticipated'] as num?)?.toInt() ?? 0,
      predictionsSubmitted:
          (json['predictionsSubmitted'] as num?)?.toInt() ?? 0,
      missionsCompleted: (json['missionsCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}

class PassportClanSummary {
  const PassportClanSummary({
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

  factory PassportClanSummary.fromJson(Map<String, dynamic> json) {
    return PassportClanSummary(
      slug: json['slug']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      role: json['role']?.toString(),
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

class PassportIdentity {
  const PassportIdentity({
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.city,
    this.countryCode,
    this.supporterSinceYear,
    this.memberSince,
  });

  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? countryCode;
  final int? supporterSinceYear;
  final String? memberSince;

  factory PassportIdentity.fromJson(Map<String, dynamic> json) {
    return PassportIdentity(
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      countryCode: json['countryCode'] as String?,
      supporterSinceYear: (json['supporterSinceYear'] as num?)?.toInt(),
      memberSince: json['memberSince'] as String?,
    );
  }
}

class PassportLevel {
  const PassportLevel({
    required this.number,
    required this.name,
    required this.points,
    required this.levelMinPoints,
    this.nextLevelPoints,
    required this.progressPercent,
    required this.pointsToNextLevel,
  });

  final int number;
  final String name;
  final int points;
  final int levelMinPoints;
  final int? nextLevelPoints;
  final int progressPercent;
  final int pointsToNextLevel;

  double get progressFraction => (progressPercent / 100).clamp(0.0, 1.0);

  factory PassportLevel.fromJson(Map<String, dynamic> json) {
    return PassportLevel(
      number: (json['number'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      levelMinPoints: (json['levelMinPoints'] as num?)?.toInt() ?? 0,
      nextLevelPoints: (json['nextLevelPoints'] as num?)?.toInt(),
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
      pointsToNextLevel: (json['pointsToNextLevel'] as num?)?.toInt() ?? 0,
    );
  }
}

class PassportStats {
  const PassportStats({
    required this.checkIns,
    required this.predictions,
    required this.predictionPoints,
    required this.posts,
    this.streakCurrent = 0,
    this.streakBest = 0,
  });

  final int checkIns;
  final int predictions;
  final int predictionPoints;
  final int posts;
  final int streakCurrent;
  final int streakBest;

  factory PassportStats.fromJson(Map<String, dynamic> json) {
    return PassportStats(
      checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
      predictions: (json['predictions'] as num?)?.toInt() ?? 0,
      predictionPoints: (json['predictionPoints'] as num?)?.toInt() ?? 0,
      posts: (json['posts'] as num?)?.toInt() ?? 0,
      streakCurrent: (json['streakCurrent'] as num?)?.toInt() ?? 0,
      streakBest: (json['streakBest'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileUpdateRequest {
  const ProfileUpdateRequest({
    this.displayName,
    this.bio,
    this.city,
    this.countryCode,
    this.supporterSinceYear,
    this.profileVisibility,
  });

  final String? displayName;
  final String? bio;
  final String? city;
  final String? countryCode;
  final int? supporterSinceYear;
  final String? profileVisibility;

  Map<String, dynamic> toJson() {
    return {
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (city != null) 'city': city,
      if (countryCode != null) 'countryCode': countryCode,
      if (supporterSinceYear != null) 'supporterSinceYear': supporterSinceYear,
      if (profileVisibility != null) 'profileVisibility': profileVisibility,
    };
  }
}
