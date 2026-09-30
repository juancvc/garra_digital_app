/// Backend-confirmed mention. Offsets are UTF-16 code units (Dart String indices).
class MentionSpan {
  const MentionSpan({required this.userId, required this.usernameSnapshot,
    required this.start, required this.end});

  final String userId;
  final String usernameSnapshot;
  final int start;
  final int end;

  factory MentionSpan.fromJson(Map<String, dynamic> json) => MentionSpan(
    userId: json['userId']?.toString() ?? '',
    usernameSnapshot: json['usernameSnapshot']?.toString() ?? '',
    start: (json['start'] as num?)?.toInt() ?? -1,
    end: (json['end'] as num?)?.toInt() ?? -1,
  );

  bool validFor(String text) => userId.isNotEmpty && start >= 0 &&
      end > start && end <= text.length &&
      text.substring(start, end).toLowerCase() ==
          '@${usernameSnapshot.toLowerCase()}';
}

List<MentionSpan> parseMentionSpans(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((value) => MentionSpan.fromJson(
    Map<String, dynamic>.from(value),
  )).toList();
}
