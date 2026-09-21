class RealtimeEnvelope {
  const RealtimeEnvelope({
    required this.eventId,
    required this.type,
    required this.version,
    required this.matchId,
    required this.occurredAt,
    required this.payload,
  });

  final String eventId;
  final String type;
  final int version;
  final String matchId;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  factory RealtimeEnvelope.fromJson(Map<String, dynamic> json) {
    return RealtimeEnvelope(
      eventId: json['eventId']?.toString() ?? '',
      type: json['type'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      matchId: json['matchId']?.toString() ?? '',
      occurredAt: json['occurredAt'] == null
          ? DateTime.now().toUtc()
          : DateTime.tryParse(json['occurredAt'].toString())?.toUtc() ??
              DateTime.now().toUtc(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }
}

abstract final class RealtimeEventTypes {
  static const matchUpdated = 'MATCH_UPDATED';
  static const matchScoringCompleted = 'MATCH_SCORING_COMPLETED';
  static const pollUpdated = 'POLL_UPDATED';
  static const postCreated = 'POST_CREATED';
  static const postEngagementUpdated = 'POST_ENGAGEMENT_UPDATED';
  static const commentCreated = 'COMMENT_CREATED';
}
