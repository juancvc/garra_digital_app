import 'package:flutter/foundation.dart';

import 'community_service.dart';

/// ANALYTICS_12: session-level (in-memory) dedupe for view registration.
///
/// The backend is the dedupe authority (viewer+target, rolling 24h); this
/// cache only avoids re-sending the same view while the app process lives.
/// An id is remembered as soon as it is attempted, so a failed request is not
/// retried in the same session (views are best-effort analytics).
class GarraViewTracker {
  GarraViewTracker._();

  static final GarraViewTracker instance = GarraViewTracker._();

  final Set<String> _posts = <String>{};
  final Set<String> _profiles = <String>{};

  bool hasTrackedPost(String postId) => _posts.contains(postId);

  bool hasTrackedProfile(String userId) => _profiles.contains(userId);

  /// Registers a view of someone else's post once per session.
  /// Returns the new total when the backend counted it, otherwise null.
  Future<int?> trackPostView(CommunityService service, String postId) async {
    final id = postId.trim();
    if (id.isEmpty || !_posts.add(id)) return null;
    final result = await service.registerPostView(id);
    if (result == null || !result.counted) return null;
    return result.viewCount;
  }

  /// Registers a visit to someone else's profile once per session.
  Future<bool> trackProfileView(CommunityService service, String userId) async {
    final id = userId.trim();
    if (id.isEmpty || !_profiles.add(id)) return false;
    return service.registerProfileView(id);
  }

  @visibleForTesting
  void resetForTest() {
    _posts.clear();
    _profiles.clear();
  }
}
