import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mission_models.dart';
import '../../data/mission_service.dart';

final missionServiceProvider = Provider<MissionService>((ref) {
  return MissionService();
});

class MissionsQuery {
  const MissionsQuery({this.matchId, this.active = true});

  final String? matchId;
  final bool active;

  @override
  bool operator ==(Object other) {
    return other is MissionsQuery &&
        other.matchId == matchId &&
        other.active == active;
  }

  @override
  int get hashCode => Object.hash(matchId, active);
}

final myMissionsProvider = FutureProvider.autoDispose
    .family<List<MissionModel>, MissionsQuery>((ref, query) {
  final service = ref.watch(missionServiceProvider);
  if (query.matchId != null && query.matchId!.isNotEmpty) {
    return service.getMyMissionsForMatch(
      query.matchId!,
      active: query.active,
    );
  }
  return service.getMyMissions(active: query.active);
});
