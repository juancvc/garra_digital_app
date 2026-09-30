import '../../../core/widgets/mention_autocomplete.dart';
import 'community_service.dart';

Future<List<MentionCandidate>> searchGlobalMentions(
    CommunityService service, String query) async {
  if (query.trim().length < 2) return const [];
  final data = await service.globalSearch(query, type: 'FANS');
  final raw = data['fans'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((item) => MentionCandidate(
    id: item['id']?.toString() ?? '',
    username: item['username']?.toString() ?? '',
    displayName: item['displayName']?.toString() ?? '',
  )).where((item) => item.id.isNotEmpty &&
      isMentionableUsername(item.username)).toList();
}
