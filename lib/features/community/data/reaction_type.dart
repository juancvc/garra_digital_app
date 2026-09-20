/// Reaction types for community posts (WallPostResponse.myReaction).
enum ReactionType {
  like('LIKE', '👍', 'Me gusta'),
  love('LOVE', '❤️', 'Me encanta'),
  fire('FIRE', '🔥', 'Está que arde'),
  anger('ANGER', '😡', 'Me enoja'),
  sad('SAD', '😢', 'Me entristece'),
  garra('GARRA', '🛡', 'Garra');

  const ReactionType(this.apiValue, this.emoji, this.labelEs);

  final String apiValue;
  final String emoji;
  final String labelEs;

  static const List<ReactionType> all = ReactionType.values;

  static ReactionType? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toUpperCase();
    for (final type in ReactionType.values) {
      if (type.apiValue == normalized) return type;
    }
    return null;
  }

  static String labelFor(String apiValue) {
    return tryParse(apiValue)?.labelEs ?? apiValue;
  }

  static String emojiFor(String apiValue) {
    return tryParse(apiValue)?.emoji ?? '👍';
  }
}

const reactionSummaryKeys = [
  'LIKE',
  'LOVE',
  'FIRE',
  'ANGER',
  'SAD',
  'GARRA',
];

Map<String, int> emptyReactionSummary() {
  return {for (final key in reactionSummaryKeys) key: 0};
}

Map<String, int> parseReactionSummary(dynamic raw) {
  final summary = emptyReactionSummary();
  if (raw is! Map) return summary;

  for (final key in reactionSummaryKeys) {
    final value = raw[key];
    summary[key] = value is num ? value.toInt() : 0;
  }
  return summary;
}

/// Returns reaction types with count > 0, sorted by count desc then key order.
List<MapEntry<String, int>> topNonZeroReactions(
  Map<String, int> summary, {
  int limit = 3,
}) {
  final entries = summary.entries
      .where((e) => e.value > 0)
      .toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return reactionSummaryKeys
          .indexOf(a.key)
          .compareTo(reactionSummaryKeys.indexOf(b.key));
    });

  if (entries.length <= limit) return entries;
  return entries.take(limit).toList();
}
