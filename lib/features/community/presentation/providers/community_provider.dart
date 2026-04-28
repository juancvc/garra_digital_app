import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/community_service.dart';
import '../../data/wall_post_model.dart';
import '../../data/wall_status_model.dart';

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

final wallStatusProvider = FutureProvider<WallStatusModel?>((ref) async {
  final service = ref.read(communityServiceProvider);
  return service.getCurrentWallStatus();
});

class WallPostsParams {
  const WallPostsParams({
    required this.matchId,
    this.locationTag,
  });

  final String matchId;
  final String? locationTag;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WallPostsParams &&
            runtimeType == other.runtimeType &&
            matchId == other.matchId &&
            locationTag == other.locationTag;
  }

  @override
  int get hashCode => Object.hash(matchId, locationTag);
}

final wallPostsProvider =
FutureProvider.family<List<WallPostModel>, WallPostsParams>((ref, params) async {
  final service = ref.read(communityServiceProvider);

  return service.getPosts(
    matchId: params.matchId,
    locationTag: params.locationTag,
  );
});

final myWallPostsProvider = FutureProvider<List<WallPostModel>>((ref) async {
  final service = ref.read(communityServiceProvider);
  return service.getMyPosts();
});