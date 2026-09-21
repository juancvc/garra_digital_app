/// Fan history + Mi Año Crema API models (calendar-year period).
library;

enum FanHistoryEntryType {
  predictionSubmitted,
  predictionScored,
  matchCheckin,
  missionCompleted,
  streakUpdated,
  postCreated,
  clanJoined,
  clanPollaResult,
  unknown;

  static FanHistoryEntryType fromApi(String? raw) {
    switch (raw) {
      case 'PREDICTION_SUBMITTED':
        return FanHistoryEntryType.predictionSubmitted;
      case 'PREDICTION_SCORED':
        return FanHistoryEntryType.predictionScored;
      case 'MATCH_CHECKIN':
        return FanHistoryEntryType.matchCheckin;
      case 'MISSION_COMPLETED':
        return FanHistoryEntryType.missionCompleted;
      case 'STREAK_UPDATED':
        return FanHistoryEntryType.streakUpdated;
      case 'POST_CREATED':
        return FanHistoryEntryType.postCreated;
      case 'CLAN_JOINED':
        return FanHistoryEntryType.clanJoined;
      case 'CLAN_POLLA_RESULT':
        return FanHistoryEntryType.clanPollaResult;
      default:
        return FanHistoryEntryType.unknown;
    }
  }

  String? get apiValue {
    switch (this) {
      case FanHistoryEntryType.predictionSubmitted:
        return 'PREDICTION_SUBMITTED';
      case FanHistoryEntryType.predictionScored:
        return 'PREDICTION_SCORED';
      case FanHistoryEntryType.matchCheckin:
        return 'MATCH_CHECKIN';
      case FanHistoryEntryType.missionCompleted:
        return 'MISSION_COMPLETED';
      case FanHistoryEntryType.streakUpdated:
        return 'STREAK_UPDATED';
      case FanHistoryEntryType.postCreated:
        return 'POST_CREATED';
      case FanHistoryEntryType.clanJoined:
        return 'CLAN_JOINED';
      case FanHistoryEntryType.clanPollaResult:
        return 'CLAN_POLLA_RESULT';
      case FanHistoryEntryType.unknown:
        return null;
    }
  }

  HistoryCardVariant get cardVariant {
    switch (this) {
      case FanHistoryEntryType.predictionSubmitted:
      case FanHistoryEntryType.predictionScored:
        return HistoryCardVariant.prediction;
      case FanHistoryEntryType.matchCheckin:
        return HistoryCardVariant.checkin;
      case FanHistoryEntryType.missionCompleted:
        return HistoryCardVariant.mission;
      case FanHistoryEntryType.streakUpdated:
        return HistoryCardVariant.streak;
      case FanHistoryEntryType.postCreated:
        return HistoryCardVariant.community;
      case FanHistoryEntryType.clanJoined:
      case FanHistoryEntryType.clanPollaResult:
        return HistoryCardVariant.clan;
      case FanHistoryEntryType.unknown:
        return HistoryCardVariant.community;
    }
  }
}

enum HistoryCardVariant {
  prediction,
  checkin,
  mission,
  streak,
  community,
  clan,
}

/// Simple timeline filters mapped to backend entry types.
enum HistoryFilter {
  all('Todo', null),
  polla('Polla', 'PREDICTION_SCORED'),
  matchday('Matchday', 'MATCH_CHECKIN'),
  missions('Misiones', 'MISSION_COMPLETED'),
  community('Comunidad', 'POST_CREATED'),
  clans('Comunidades', 'CLAN_JOINED');

  const HistoryFilter(this.label, this.backendType);

  final String label;
  final String? backendType;
}

class FanHistoryEntry {
  const FanHistoryEntry({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.calendarYear,
    required this.title,
    this.referenceType,
    this.referenceId,
    this.subtitle,
    this.metadata = const {},
  });

  final String id;
  final FanHistoryEntryType type;
  final DateTime occurredAt;
  final int calendarYear;
  final String title;
  final String? referenceType;
  final String? referenceId;
  final String? subtitle;
  final Map<String, dynamic> metadata;

  HistoryCardVariant get variant => type.cardVariant;

  factory FanHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawType =
        (json['type'] ?? json['entryType'])?.toString();
    final meta = json['metadata'] ?? json['metadataJson'];
    Map<String, dynamic> metadata = const {};
    if (meta is Map) {
      metadata = Map<String, dynamic>.from(meta);
    }

    final occurredRaw = json['occurredAt']?.toString();
    return FanHistoryEntry(
      id: json['id']?.toString() ?? '',
      type: FanHistoryEntryType.fromApi(rawType),
      occurredAt: occurredRaw == null || occurredRaw.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.parse(occurredRaw),
      calendarYear: (json['calendarYear'] as num?)?.toInt() ??
          DateTime.now().year,
      title: json['title'] as String? ?? 'Momento crema',
      referenceType: json['referenceType']?.toString(),
      referenceId: json['referenceId']?.toString(),
      subtitle: json['subtitle'] as String? ??
          metadata['subtitle']?.toString() ??
          metadata['detail']?.toString(),
      metadata: metadata,
    );
  }
}

class HistoryPageResult {
  const HistoryPageResult({
    required this.items,
    this.nextCursor,
    this.hasNext = false,
    this.size = 0,
  });

  final List<FanHistoryEntry> items;
  final String? nextCursor;
  final bool hasNext;
  final int size;

  factory HistoryPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final page = json['page'] is Map
        ? Map<String, dynamic>.from(json['page'] as Map)
        : <String, dynamic>{};

    return HistoryPageResult(
      items: rawItems
          .map(
            (e) => FanHistoryEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      size: (page['size'] as num?)?.toInt() ??
          (json['size'] as num?)?.toInt() ??
          rawItems.length,
      hasNext: page['hasNext'] as bool? ??
          json['hasNext'] as bool? ??
          false,
      nextCursor: (page['nextCursor'] ?? json['nextCursor'])?.toString(),
    );
  }
}

class YearRecapIdentity {
  const YearRecapIdentity({
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.levelNumber,
    this.levelName,
  });

  final String displayName;
  final String? username;
  final String? avatarUrl;
  final int? levelNumber;
  final String? levelName;

  factory YearRecapIdentity.fromJson(Map<String, dynamic> json) {
    return YearRecapIdentity(
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      levelNumber: (json['levelNumber'] as num?)?.toInt(),
      levelName: json['levelName'] as String?,
    );
  }
}

class YearRecapHeadline {
  const YearRecapHeadline({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  factory YearRecapHeadline.fromJson(Map<String, dynamic> json) {
    return YearRecapHeadline(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
    );
  }
}

class YearRecapStats {
  const YearRecapStats({
    this.pointsEarned = 0,
    this.matchdaysParticipated = 0,
    this.checkIns = 0,
    this.stadiumCheckIns = 0,
    this.missionsCompleted = 0,
  });

  final int pointsEarned;
  final int matchdaysParticipated;
  final int checkIns;
  final int stadiumCheckIns;
  final int missionsCompleted;

  factory YearRecapStats.fromJson(Map<String, dynamic> json) {
    return YearRecapStats(
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      matchdaysParticipated:
          (json['matchdaysParticipated'] as num?)?.toInt() ?? 0,
      checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
      stadiumCheckIns: (json['stadiumCheckIns'] as num?)?.toInt() ?? 0,
      missionsCompleted: (json['missionsCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}

class YearRecapPrediction {
  const YearRecapPrediction({
    this.submitted = 0,
    this.scored = 0,
    this.points = 0,
    this.exactScores = 0,
    this.correctOutcomes = 0,
  });

  final int submitted;
  final int scored;
  final int points;
  final int exactScores;
  final int correctOutcomes;

  factory YearRecapPrediction.fromJson(Map<String, dynamic> json) {
    return YearRecapPrediction(
      submitted: (json['submitted'] as num?)?.toInt() ??
          (json['predictionsSubmitted'] as num?)?.toInt() ??
          0,
      scored: (json['scored'] as num?)?.toInt() ??
          (json['predictionsScored'] as num?)?.toInt() ??
          0,
      points: (json['points'] as num?)?.toInt() ??
          (json['predictionPoints'] as num?)?.toInt() ??
          0,
      exactScores: (json['exactScores'] as num?)?.toInt() ?? 0,
      correctOutcomes: (json['correctOutcomes'] as num?)?.toInt() ?? 0,
    );
  }
}

class YearRecapMatchday {
  const YearRecapMatchday({
    this.participated = 0,
    this.checkIns = 0,
    this.stadiumCheckIns = 0,
  });

  final int participated;
  final int checkIns;
  final int stadiumCheckIns;

  factory YearRecapMatchday.fromJson(Map<String, dynamic> json) {
    return YearRecapMatchday(
      participated: (json['participated'] as num?)?.toInt() ??
          (json['matchdaysParticipated'] as num?)?.toInt() ??
          0,
      checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
      stadiumCheckIns: (json['stadiumCheckIns'] as num?)?.toInt() ?? 0,
    );
  }
}

class YearRecapCommunity {
  const YearRecapCommunity({
    this.posts = 0,
    this.comments = 0,
    this.reactions = 0,
  });

  final int posts;
  final int comments;
  final int reactions;

  factory YearRecapCommunity.fromJson(Map<String, dynamic> json) {
    return YearRecapCommunity(
      posts: (json['posts'] as num?)?.toInt() ??
          (json['postsCreated'] as num?)?.toInt() ??
          0,
      comments: (json['comments'] as num?)?.toInt() ??
          (json['commentsCreated'] as num?)?.toInt() ??
          0,
      reactions: (json['reactions'] as num?)?.toInt() ??
          (json['reactionsGiven'] as num?)?.toInt() ??
          0,
    );
  }
}

class YearRecapStreak {
  const YearRecapStreak({this.best = 0});

  final int best;

  factory YearRecapStreak.fromJson(Map<String, dynamic> json) {
    return YearRecapStreak(
      best: (json['best'] as num?)?.toInt() ??
          (json['bestStreak'] as num?)?.toInt() ??
          0,
    );
  }
}

class YearRecapClan {
  const YearRecapClan({
    this.name,
    this.slug,
    this.pollaPoints = 0,
    this.joinedCount = 0,
  });

  final String? name;
  final String? slug;
  final int pollaPoints;
  final int joinedCount;

  bool get hasClan => name != null && name!.trim().isNotEmpty;

  factory YearRecapClan.fromJson(Map<String, dynamic> json) {
    final primary = json['primaryClan'] is Map
        ? Map<String, dynamic>.from(json['primaryClan'] as Map)
        : null;
    return YearRecapClan(
      name: (json['name'] ?? primary?['name']) as String?,
      slug: (json['slug'] ?? primary?['slug'])?.toString(),
      pollaPoints: (json['pollaPoints'] as num?)?.toInt() ??
          (json['clanPollaPoints'] as num?)?.toInt() ??
          (json['clanPollaPointsContributed'] as num?)?.toInt() ??
          0,
      joinedCount: (json['joinedCount'] as num?)?.toInt() ??
          (json['clansJoined'] as num?)?.toInt() ??
          0,
    );
  }
}

class YearRecapHighlight {
  const YearRecapHighlight({
    required this.text,
    this.kind,
  });

  final String text;
  final String? kind;

  factory YearRecapHighlight.fromJson(Map<String, dynamic> json) {
    return YearRecapHighlight(
      text: (json['text'] ?? json['message'] ?? json['title']) as String? ?? '',
      kind: json['kind']?.toString() ?? json['type']?.toString(),
    );
  }
}

/// Safe share DTO — no email, phone, coordinates, or private content.
class FanYearShareDto {
  const FanYearShareDto({
    required this.displayName,
    required this.year,
    this.username,
    this.levelName,
    this.bestStreak,
    this.predictionPoints,
    this.matchdaysParticipated,
    this.missionsCompleted,
    this.pointsEarned,
    this.primaryClanName,
    this.tagline,
  });

  final String displayName;
  final int year;
  final String? username;
  final String? levelName;
  final int? bestStreak;
  final int? predictionPoints;
  final int? matchdaysParticipated;
  final int? missionsCompleted;
  final int? pointsEarned;
  final String? primaryClanName;
  final String? tagline;

  factory FanYearShareDto.fromJson(Map<String, dynamic> json) {
    return FanYearShareDto(
      displayName: json['displayName'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      username: json['username'] as String?,
      levelName: json['levelName'] as String? ?? json['level'] as String?,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ??
          (json['streak'] as num?)?.toInt(),
      predictionPoints: (json['predictionPoints'] as num?)?.toInt(),
      matchdaysParticipated:
          (json['matchdaysParticipated'] as num?)?.toInt(),
      missionsCompleted: (json['missionsCompleted'] as num?)?.toInt(),
      pointsEarned: (json['pointsEarned'] as num?)?.toInt(),
      primaryClanName: json['primaryClanName'] as String? ??
          (json['primaryClan'] is Map
              ? (json['primaryClan'] as Map)['name'] as String?
              : null),
      tagline: json['tagline'] as String?,
    );
  }

  /// Fields safe to render on a public share card.
  Set<String> get safeFieldNames => {
        'displayName',
        'year',
        if (username != null) 'username',
        if (levelName != null) 'levelName',
        if (bestStreak != null) 'bestStreak',
        if (predictionPoints != null) 'predictionPoints',
        if (matchdaysParticipated != null) 'matchdaysParticipated',
        if (missionsCompleted != null) 'missionsCompleted',
        if (pointsEarned != null) 'pointsEarned',
        if (primaryClanName != null) 'primaryClanName',
        if (tagline != null) 'tagline',
      };
}

class YearRecapModel {
  const YearRecapModel({
    required this.year,
    required this.identity,
    required this.headline,
    required this.stats,
    required this.prediction,
    required this.matchday,
    required this.community,
    required this.streak,
    required this.clan,
    required this.highlights,
    required this.share,
  });

  final int year;
  final YearRecapIdentity identity;
  final YearRecapHeadline headline;
  final YearRecapStats stats;
  final YearRecapPrediction prediction;
  final YearRecapMatchday matchday;
  final YearRecapCommunity community;
  final YearRecapStreak streak;
  final YearRecapClan clan;
  final List<YearRecapHighlight> highlights;
  final FanYearShareDto share;

  bool get hasMeaningfulActivity =>
      stats.pointsEarned > 0 ||
      stats.matchdaysParticipated > 0 ||
      stats.missionsCompleted > 0 ||
      prediction.submitted > 0 ||
      prediction.points > 0 ||
      community.posts > 0 ||
      community.comments > 0 ||
      community.reactions > 0 ||
      streak.best > 0 ||
      clan.hasClan ||
      clan.pollaPoints > 0;

  factory YearRecapModel.fromJson(Map<String, dynamic> json) {
    final year = (json['year'] as num?)?.toInt() ?? DateTime.now().year;
    final identityJson = json['identity'] is Map
        ? Map<String, dynamic>.from(json['identity'] as Map)
        : <String, dynamic>{};
    final headlineJson = json['headline'] is Map
        ? Map<String, dynamic>.from(json['headline'] as Map)
        : <String, dynamic>{
            'title': 'Este fue tu $year crema',
          };
    final statsJson = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : <String, dynamic>{};
    final predictionJson = json['prediction'] is Map
        ? Map<String, dynamic>.from(json['prediction'] as Map)
        : <String, dynamic>{};
    final matchdayJson = json['matchday'] is Map
        ? Map<String, dynamic>.from(json['matchday'] as Map)
        : <String, dynamic>{};
    final communityJson = json['community'] is Map
        ? Map<String, dynamic>.from(json['community'] as Map)
        : <String, dynamic>{};
    final streakJson = json['streak'] is Map
        ? Map<String, dynamic>.from(json['streak'] as Map)
        : <String, dynamic>{};
    final clanJson = json['clan'] is Map
        ? Map<String, dynamic>.from(json['clan'] as Map)
        : <String, dynamic>{};
    final shareJson = json['share'] is Map
        ? Map<String, dynamic>.from(json['share'] as Map)
        : <String, dynamic>{
            'displayName': identityJson['displayName'] ?? '',
            'year': year,
          };
    final rawHighlights = json['highlights'] as List? ?? const [];

    return YearRecapModel(
      year: year,
      identity: YearRecapIdentity.fromJson(identityJson),
      headline: YearRecapHeadline.fromJson(headlineJson),
      stats: YearRecapStats.fromJson(statsJson),
      prediction: YearRecapPrediction.fromJson(predictionJson),
      matchday: YearRecapMatchday.fromJson(matchdayJson),
      community: YearRecapCommunity.fromJson(communityJson),
      streak: YearRecapStreak.fromJson(streakJson),
      clan: YearRecapClan.fromJson(clanJson),
      highlights: rawHighlights
          .map(
            (e) => YearRecapHighlight.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .where((h) => h.text.trim().isNotEmpty)
          .toList(),
      share: FanYearShareDto.fromJson(shareJson),
    );
  }
}
