/// One row of "who reacted" (GET /community/posts/{id}/reactions and
/// /community/comments/{id}/reactions). Public data only.
class ReactorItem {
  const ReactorItem({
    required this.fanId,
    required this.username,
    required this.displayName,
    required this.type,
    this.avatarUrl,
  });

  final String fanId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String type;

  factory ReactorItem.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? '';
    final display = json['displayName']?.toString() ?? '';
    return ReactorItem(
      fanId: json['fanId']?.toString() ?? '',
      username: username,
      displayName: display.trim().isEmpty ? username : display,
      avatarUrl: json['avatarUrl']?.toString(),
      type: json['type']?.toString() ?? '',
    );
  }
}

class ReactorsPage {
  const ReactorsPage({
    required this.items,
    this.hasNext = false,
    this.nextCursor,
  });

  final List<ReactorItem> items;
  final bool hasNext;
  final String? nextCursor;

  factory ReactorsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? const [];
    final page = json['page'] is Map
        ? Map<String, dynamic>.from(json['page'] as Map)
        : const <String, dynamic>{};
    return ReactorsPage(
      items: raw
          .whereType<Map>()
          .map((e) => ReactorItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasNext: page['hasNext'] == true,
      nextCursor: page['nextCursor']?.toString(),
    );
  }
}