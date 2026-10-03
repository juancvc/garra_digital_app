import '../../clans/data/clan_models.dart';
import 'wall_post_model.dart';

/// Person suggested by `GET /community/discovery`.
///
/// [accountType] comes from the backend; the official account is recognised
/// only through it (see `isPlatformOfficialAccount`), never by name.
class DiscoveryPerson {
  const DiscoveryPerson({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.accountType = 'STANDARD',
    this.reason = '',
  });

  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String accountType;

  /// Backend reason code: `OFFICIAL_ACCOUNT` | `ACTIVE_IN_COMMUNITY`.
  final String reason;

  factory DiscoveryPerson.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? '';
    final name = json['displayName']?.toString() ?? '';
    return DiscoveryPerson(
      userId: json['userId']?.toString() ?? '',
      username: username,
      displayName: name.trim().isEmpty ? username : name,
      avatarUrl: json['avatarUrl'] as String?,
      accountType: json['accountType']?.toString() ?? 'STANDARD',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

/// Verified Solidaria initiative highlight (no contact data by contract).
class DiscoverySolidarity {
  const DiscoverySolidarity({
    required this.id,
    required this.title,
    required this.type,
    this.city,
    this.district,
  });

  final String id;
  final String title;
  final String type;
  final String? city;
  final String? district;

  factory DiscoverySolidarity.fromJson(Map<String, dynamic> json) {
    return DiscoverySolidarity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'OTHER',
      city: json['city'] as String?,
      district: json['district'] as String?,
    );
  }
}

/// Composite payload of `GET /community/discovery`.
class DiscoveryBundle {
  const DiscoveryBundle({
    this.people = const [],
    this.communities = const [],
    this.posts = const [],
    this.solidarity = const [],
  });

  final List<DiscoveryPerson> people;
  final List<ClanModel> communities;
  final List<WallPostModel> posts;
  final List<DiscoverySolidarity> solidarity;

  bool get isEmpty =>
      people.isEmpty &&
      communities.isEmpty &&
      posts.isEmpty &&
      solidarity.isEmpty;

  factory DiscoveryBundle.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) map) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    return DiscoveryBundle(
      people: parse('people', DiscoveryPerson.fromJson),
      communities: parse('communities', ClanModel.fromJson),
      posts: parse('posts', WallPostModel.fromJson),
      solidarity: parse('solidarity', DiscoverySolidarity.fromJson),
    );
  }
}
