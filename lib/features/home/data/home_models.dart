class HomeModel {
  const HomeModel({
    required this.fan,
    required this.matchdayState,
    this.match,
    required this.prediction,
    required this.checkIn,
    required this.community,
    required this.notifications,
  });

  final HomeFanSummary fan;
  final String matchdayState;
  final HomeMatch? match;
  final HomePrediction prediction;
  final HomeCheckIn checkIn;
  final HomeCommunityPreview community;
  final HomeNotifications notifications;

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
    this.pointsEarned,
    required this.predictionsOpen,
  });

  final String state;
  final String? matchId;
  final int? predictedHomeScore;
  final int? predictedAwayScore;
  final int? pointsEarned;
  final bool predictionsOpen;

  factory HomePrediction.fromJson(Map<String, dynamic> json) {
    return HomePrediction(
      state: json['state'] as String? ?? 'NOT_PREDICTED',
      matchId: json['matchId']?.toString(),
      predictedHomeScore: (json['predictedHomeScore'] as num?)?.toInt(),
      predictedAwayScore: (json['predictedAwayScore'] as num?)?.toInt(),
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
  });

  final String id;
  final String username;
  final String displayName;
  final String content;
  final String? locationTag;
  final DateTime createdAt;

  factory HomeCommunityPost.fromJson(Map<String, dynamic> json) {
    return HomeCommunityPost(
      id: json['id'].toString(),
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      locationTag: json['locationTag'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
