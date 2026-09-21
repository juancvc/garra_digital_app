class SeasonModel {
  SeasonModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.startsAt,
    this.endsAt,
    required this.status,
    this.themeKey,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? startsAt;
  final String? endsAt;
  final String status;
  final String? themeKey;

  factory SeasonModel.fromJson(Map<String, dynamic> json) => SeasonModel(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        startsAt: json['startsAt']?.toString(),
        endsAt: json['endsAt']?.toString(),
        status: json['status']?.toString() ?? 'DRAFT',
        themeKey: json['themeKey']?.toString(),
      );
}

class SeasonProgressModel {
  SeasonProgressModel({
    required this.seasonId,
    required this.seasonName,
    required this.pointsEarned,
    required this.missionsCompleted,
    required this.checkIns,
    required this.globalPosts,
    required this.comments,
    required this.reactionsReceived,
    required this.communitiesJoined,
    required this.businessesFollowed,
    required this.solidarityParticipations,
    required this.matchdayParticipations,
    required this.streakBest,
    required this.referralsCompleted,
    required this.achievementsUnlocked,
    required this.eventCheckins,
  });

  final String seasonId;
  final String seasonName;
  final int pointsEarned;
  final int missionsCompleted;
  final int checkIns;
  final int globalPosts;
  final int comments;
  final int reactionsReceived;
  final int communitiesJoined;
  final int businessesFollowed;
  final int solidarityParticipations;
  final int matchdayParticipations;
  final int streakBest;
  final int referralsCompleted;
  final int achievementsUnlocked;
  final int eventCheckins;

  factory SeasonProgressModel.fromJson(Map<String, dynamic> json) =>
      SeasonProgressModel(
        seasonId: json['seasonId']?.toString() ?? '',
        seasonName: json['seasonName']?.toString() ?? '',
        pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
        missionsCompleted: (json['missionsCompleted'] as num?)?.toInt() ?? 0,
        checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
        globalPosts: (json['globalPosts'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
        reactionsReceived: (json['reactionsReceived'] as num?)?.toInt() ?? 0,
        communitiesJoined: (json['communitiesJoined'] as num?)?.toInt() ?? 0,
        businessesFollowed: (json['businessesFollowed'] as num?)?.toInt() ?? 0,
        solidarityParticipations:
            (json['solidarityParticipations'] as num?)?.toInt() ?? 0,
        matchdayParticipations:
            (json['matchdayParticipations'] as num?)?.toInt() ?? 0,
        streakBest: (json['streakBest'] as num?)?.toInt() ?? 0,
        referralsCompleted: (json['referralsCompleted'] as num?)?.toInt() ?? 0,
        achievementsUnlocked: (json['achievementsUnlocked'] as num?)?.toInt() ?? 0,
        eventCheckins: (json['eventCheckins'] as num?)?.toInt() ?? 0,
      );
}

class SeasonRecapModel {
  SeasonRecapModel({
    required this.seasonId,
    required this.seasonName,
    required this.pointsEarned,
    required this.achievementsUnlocked,
    required this.streakBest,
    required this.checkIns,
    required this.communitiesJoined,
    required this.highlight,
  });

  final String seasonId;
  final String seasonName;
  final int pointsEarned;
  final int achievementsUnlocked;
  final int streakBest;
  final int checkIns;
  final int communitiesJoined;
  final String highlight;

  factory SeasonRecapModel.fromJson(Map<String, dynamic> json) =>
      SeasonRecapModel(
        seasonId: json['seasonId']?.toString() ?? '',
        seasonName: json['seasonName']?.toString() ?? '',
        pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
        achievementsUnlocked: (json['achievementsUnlocked'] as num?)?.toInt() ?? 0,
        streakBest: (json['streakBest'] as num?)?.toInt() ?? 0,
        checkIns: (json['checkIns'] as num?)?.toInt() ?? 0,
        communitiesJoined: (json['communitiesJoined'] as num?)?.toInt() ?? 0,
        highlight: json['highlight']?.toString() ?? '',
      );
}

class AchievementModel {
  AchievementModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.iconKey,
    required this.rarity,
    required this.secret,
    required this.unlocked,
    this.unlockedAt,
    this.progress,
    this.target,
    required this.nearUnlock,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final String category;
  final String iconKey;
  final String rarity;
  final bool secret;
  final bool unlocked;
  final String? unlockedAt;
  final int? progress;
  final int? target;
  final bool nearUnlock;

  factory AchievementModel.fromJson(Map<String, dynamic> json) =>
      AchievementModel(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        iconKey: json['iconKey']?.toString() ?? '',
        rarity: json['rarity']?.toString() ?? 'COMMON',
        secret: json['secret'] == true,
        unlocked: json['unlocked'] == true,
        unlockedAt: json['unlockedAt']?.toString(),
        progress: (json['progress'] as num?)?.toInt(),
        target: (json['target'] as num?)?.toInt(),
        nearUnlock: json['nearUnlock'] == true,
      );
}

class CollectionItemModel {
  CollectionItemModel({
    required this.id,
    required this.kind,
    required this.name,
    required this.category,
    required this.status,
    this.at,
    this.detail,
  });

  final String id;
  final String kind;
  final String name;
  final String category;
  final String status;
  final String? at;
  final String? detail;

  String get dateLabel => at ?? '';

  factory CollectionItemModel.fromJson(Map<String, dynamic> json) =>
      CollectionItemModel(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        at: json['at']?.toString(),
        detail: json['detail']?.toString(),
      );
}

class DailyGarraModel {
  DailyGarraModel({
    required this.type,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.destination,
  });

  final String type;
  final String title;
  final String message;
  final String ctaLabel;
  final String destination;

  factory DailyGarraModel.fromJson(Map<String, dynamic> json) => DailyGarraModel(
        type: json['type']?.toString() ?? 'COMMUNITY',
        title: json['title']?.toString() ?? 'Hoy en Garra',
        message: json['message']?.toString() ?? '',
        ctaLabel: json['ctaLabel']?.toString() ?? 'Ver',
        destination: json['destination']?.toString() ?? '/comunidad',
      );
}

class GarraEventModel {
  GarraEventModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.city,
    this.district,
    this.address,
    this.latitude,
    this.longitude,
    this.startsAt,
    this.endsAt,
    this.capacity,
    required this.status,
    required this.verificationStatus,
    required this.verifiedByGarra,
    this.myParticipation,
    required this.checkedIn,
    this.checkInLabel,
  });

  final String id;
  final String title;
  final String? description;
  final String type;
  final String? city;
  final String? district;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? startsAt;
  final String? endsAt;
  final int? capacity;
  final String status;
  final String verificationStatus;
  final bool verifiedByGarra;
  final String? myParticipation;
  final bool checkedIn;
  final String? checkInLabel;

  factory GarraEventModel.fromJson(Map<String, dynamic> json) => GarraEventModel(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString(),
        type: json['type']?.toString() ?? 'OTHER',
        city: json['city']?.toString(),
        district: json['district']?.toString(),
        address: json['address']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        startsAt: json['startsAt']?.toString(),
        endsAt: json['endsAt']?.toString(),
        capacity: (json['capacity'] as num?)?.toInt(),
        status: json['status']?.toString() ?? 'DRAFT',
        verificationStatus: json['verificationStatus']?.toString() ?? 'PENDING',
        verifiedByGarra: json['verifiedByGarra'] == true,
        myParticipation: json['myParticipation']?.toString(),
        checkedIn: json['checkedIn'] == true,
        checkInLabel: json['checkInLabel']?.toString(),
      );

  String get zoneLabel {
    final parts = [district, city].where((e) => e != null && e.trim().isNotEmpty);
    return parts.isEmpty ? 'Ubicación por confirmar' : parts.join(' · ');
  }
}

class InterestPreferencesModel {
  InterestPreferencesModel({
    this.city,
    this.region,
    required this.interests,
    required this.onboardingCompleted,
  });

  final String? city;
  final String? region;
  final List<String> interests;
  final bool onboardingCompleted;

  factory InterestPreferencesModel.fromJson(Map<String, dynamic> json) =>
      InterestPreferencesModel(
        city: json['city']?.toString(),
        region: json['region']?.toString(),
        interests: (json['interests'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        onboardingCompleted: json['onboardingCompleted'] == true,
      );
}

class BusinessRatingSummary {
  BusinessRatingSummary({
    this.averageRating,
    required this.reviewCount,
    required this.label,
    required this.reviews,
  });

  final double? averageRating;
  final int reviewCount;
  final String label;
  final List<BusinessReviewModel> reviews;

  factory BusinessRatingSummary.fromJson(Map<String, dynamic> json) =>
      BusinessRatingSummary(
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        label: json['label']?.toString() ?? 'Opiniones de la comunidad',
        reviews: (json['reviews'] as List? ?? const [])
            .map((e) =>
                BusinessReviewModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class BusinessReviewModel {
  BusinessReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    this.username,
    this.fullName,
  });

  final String id;
  final int rating;
  final String? comment;
  final String? username;
  final String? fullName;

  factory BusinessReviewModel.fromJson(Map<String, dynamic> json) =>
      BusinessReviewModel(
        id: json['id']?.toString() ?? '',
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        comment: json['comment']?.toString(),
        username: json['username']?.toString(),
        fullName: json['fullName']?.toString(),
      );
}

const kFanInterestOptions = <(String, String)>[
  ('PARTIDOS', 'Partidos'),
  ('COMUNIDAD', 'Comunidad'),
  ('PUNTOS_CREMA', 'Puntos Crema'),
  ('EMPRENDIMIENTOS', 'Emprendimientos'),
  ('SOLIDARIA', 'Solidaria'),
  ('HISTORIA', 'Historia'),
];
