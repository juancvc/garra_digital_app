class HomeModel {
  const HomeModel({
    required this.fan,
    required this.matchdayState,
    this.match,
    required this.prediction,
    required this.checkIn,
    required this.community,
    required this.notifications,
    this.mvpOpen = false,
    this.mvpPollId,
    this.mission,
    this.streak,
    this.clan,
  });

  final HomeFanSummary fan;
  final String matchdayState;
  final HomeMatch? match;
  final HomePrediction prediction;
  final HomeCheckIn checkIn;
  final HomeCommunityPreview community;
  final HomeNotifications notifications;
  final bool mvpOpen;
  final String? mvpPollId;
  final HomeMissionSummary? mission;
  final HomeStreakSummary? streak;
  final HomeClanSummary? clan;

  factory HomeModel.fromJson(Map<String, dynamic> json) {
    return HomeModel(
      fan: HomeFanSummary.fromJson(
        Map<String, dynamic>.from(json['fan'] as Map),
      ),
      matchdayState: json['matchdayState'] as String? ?? 'NO_MATCH',
      match: json['match'] == null
          ? null
          : HomeMatch.fromJson(Map<String, dynamic>.from(json['match'] as Map)),
      prediction: HomePrediction.fromJson(
        Map<String, dynamic>.from(json['prediction'] as Map? ?? const {}),
      ),
      checkIn: HomeCheckIn.fromJson(
        Map<String, dynamic>.from(json['checkIn'] as Map? ?? const {}),
      ),
      community: HomeCommunityPreview.fromJson(
        Map<String, dynamic>.from(json['community'] as Map? ?? const {}),
      ),
      notifications: HomeNotifications.fromJson(
        Map<String, dynamic>.from(json['notifications'] as Map? ?? const {}),
      ),
      mvpOpen: json['mvpOpen'] as bool? ?? false,
      mvpPollId: json['mvpPollId']?.toString(),
      mission: json['mission'] == null
          ? null
          : HomeMissionSummary.fromJson(
              Map<String, dynamic>.from(json['mission'] as Map),
            ),
      streak: json['streak'] == null
          ? null
          : HomeStreakSummary.fromJson(
              Map<String, dynamic>.from(json['streak'] as Map),
            ),
      clan: json['clan'] == null
          ? null
          : HomeClanSummary.fromJson(
              Map<String, dynamic>.from(json['clan'] as Map),
            ),
    );
  }

  bool get isLive => matchdayState == 'LIVE';
  bool get isMatchday => matchdayState == 'MATCHDAY';
  bool get isUpcoming => matchdayState == 'UPCOMING';
  bool get isFinished => matchdayState == 'FINISHED';
  bool get hasMatch => match != null;
}

class HomeFanSummary {
  const HomeFanSummary({
    required this.displayName,
    required this.username,
    this.avatarUrl,
    required this.levelNumber,
    required this.levelName,
    required this.points,
    this.globalRank,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;
  final int levelNumber;
  final String levelName;
  final int points;
  final int? globalRank;

  factory HomeFanSummary.fromJson(Map<String, dynamic> json) {
    return HomeFanSummary(
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      levelNumber: (json['levelNumber'] as num?)?.toInt() ?? 1,
      levelName: json['levelName'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      globalRank: (json['globalRank'] as num?)?.toInt(),
    );
  }
}

class HomeMatch {
  const HomeMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchDateTime,
    required this.stadium,
    required this.competition,
    required this.status,
    required this.matchdayState,
    this.homeScore,
    this.awayScore,
    this.predictionClosesAt,
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime matchDateTime;
  final String stadium;
  final String competition;
  final String status;
  final String matchdayState;
  final int? homeScore;
  final int? awayScore;
  final DateTime? predictionClosesAt;

  factory HomeMatch.fromJson(Map<String, dynamic> json) {
    return HomeMatch(
      id: json['id'].toString(),
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      matchDateTime: DateTime.parse(json['matchDateTime'] as String),
      stadium: json['stadium'] as String? ?? '',
      competition: json['competition'] as String? ?? '',
      status: json['status'] as String? ?? '',
      matchdayState: json['matchdayState'] as String? ?? 'NO_MATCH',
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
      predictionClosesAt: json['predictionClosesAt'] == null
          ? null
          : DateTime.parse(json['predictionClosesAt'] as String),
    );
  }
}

class HomePrediction {
  const HomePrediction({
    required this.state,
    this.matchId,
    this.predictedHomeScore,
    this.predictedAwayScore,
    this.firstScorer,
    this.pointsEarned,
    required this.predictionsOpen,
  });

  final String state;
  final String? matchId;
  final int? predictedHomeScore;
  final int? predictedAwayScore;
  final String? firstScorer;
  final int? pointsEarned;
  final bool predictionsOpen;

  factory HomePrediction.fromJson(Map<String, dynamic> json) {
    return HomePrediction(
      state: json['state'] as String? ?? 'NOT_PREDICTED',
      matchId: json['matchId']?.toString(),
      predictedHomeScore: (json['predictedHomeScore'] as num?)?.toInt(),
      predictedAwayScore: (json['predictedAwayScore'] as num?)?.toInt(),
      firstScorer: json['firstScorer'] as String?,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt(),
      predictionsOpen: json['predictionsOpen'] as bool? ?? false,
    );
  }
}

class HomeCheckIn {
  const HomeCheckIn({
    required this.showCheckInCta,
    required this.hasActiveStadiumPoint,
    required this.recentlyCheckedIn,
    this.ctaLabel,
  });

  final bool showCheckInCta;
  final bool hasActiveStadiumPoint;
  final bool recentlyCheckedIn;
  final String? ctaLabel;

  factory HomeCheckIn.fromJson(Map<String, dynamic> json) {
    return HomeCheckIn(
      showCheckInCta: json['showCheckInCta'] as bool? ?? false,
      hasActiveStadiumPoint: json['hasActiveStadiumPoint'] as bool? ?? false,
      recentlyCheckedIn: json['recentlyCheckedIn'] as bool? ?? false,
      ctaLabel: json['ctaLabel'] as String?,
    );
  }
}

class HomeCommunityPreview {
  const HomeCommunityPreview({
    this.matchId,
    required this.posts,
  });

  final String? matchId;
  final List<HomeCommunityPost> posts;

  factory HomeCommunityPreview.fromJson(Map<String, dynamic> json) {
    final raw = json['posts'] as List? ?? const [];
    return HomeCommunityPreview(
      matchId: json['matchId']?.toString(),
      posts: raw
          .map((e) => HomeCommunityPost.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class HomeCommunityPost {
  const HomeCommunityPost({
    required this.id,
    required this.username,
    required this.displayName,
    required this.content,
    this.locationTag,
    required this.createdAt,
    this.reactionSummary = const {},
    this.reactionCount = 0,
    this.commentCount = 0,
    this.myReaction,
  });

  final String id;
  final String username;
  final String displayName;
  final String content;
  final String? locationTag;
  final DateTime createdAt;
  final Map<String, int> reactionSummary;
  final int reactionCount;
  final int commentCount;
  final String? myReaction;

  factory HomeCommunityPost.fromJson(Map<String, dynamic> json) {
    Map<String, int> summary = const {};
    final rawSummary = json['reactionSummary'];
    if (rawSummary is Map) {
      summary = {
        for (final entry in rawSummary.entries)
          entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
      };
    }

    return HomeCommunityPost(
      id: json['id'].toString(),
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      locationTag: json['locationTag'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reactionSummary: summary,
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      myReaction: json['myReaction']?.toString(),
    );
  }
}

class HomeNotifications {
  const HomeNotifications({required this.unreadCount});

  final int unreadCount;

  factory HomeNotifications.fromJson(Map<String, dynamic> json) {
    return HomeNotifications(
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class HomeMissionSummary {
  const HomeMissionSummary({
    required this.id,
    required this.title,
    required this.completedSteps,
    required this.totalSteps,
    required this.rewardPoints,
    required this.completed,
  });

  final String id;
  final String title;
  final int completedSteps;
  final int totalSteps;
  final int rewardPoints;
  final bool completed;

  double get progressFraction {
    if (totalSteps <= 0) return completed ? 1.0 : 0.0;
    return (completedSteps / totalSteps).clamp(0.0, 1.0);
  }

  factory HomeMissionSummary.fromJson(Map<String, dynamic> json) {
    return HomeMissionSummary(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      completedSteps: (json['completedSteps'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

class HomeStreakSummary {
  const HomeStreakSummary({
    required this.current,
    required this.best,
  });

  final int current;
  final int best;

  bool get isActive => current > 0;

  factory HomeStreakSummary.fromJson(Map<String, dynamic> json) {
    return HomeStreakSummary(
      current: (json['current'] as num?)?.toInt() ?? 0,
      best: (json['best'] as num?)?.toInt() ?? 0,
    );
  }
}

class HomeClanSummary {
  const HomeClanSummary({
    required this.slug,
    required this.name,
    required this.memberCount,
    this.role,
    this.logoUrl,
    this.currentYearPollaPoints,
    this.currentYearRank,
  });

  final String slug;
  final String name;
  final int memberCount;
  final String? role;
  final String? logoUrl;
  final int? currentYearPollaPoints;
  final int? currentYearRank;

  factory HomeClanSummary.fromJson(Map<String, dynamic> json) {
    return HomeClanSummary(
      slug: json['slug']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      role: json['role']?.toString(),
      logoUrl: json['logoUrl'] as String?,
      currentYearPollaPoints:
          (json['currentYearPollaPoints'] as num?)?.toInt() ??
              (json['currentYearPoints'] as num?)?.toInt(),
      currentYearRank: (json['currentYearRank'] as num?)?.toInt(),
    );
  }
}
