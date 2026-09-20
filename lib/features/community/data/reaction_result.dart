import 'reaction_type.dart';

class ReactionResult {
  const ReactionResult({
    required this.success,
    required this.message,
    this.myReaction,
    this.reactionSummary,
    this.reactionCount,
  });

  final bool success;
  final String message;
  final String? myReaction;
  final Map<String, int>? reactionSummary;
  final int? reactionCount;

  factory ReactionResult.success({
    required String message,
    String? myReaction,
    Map<String, int>? reactionSummary,
    int? reactionCount,
  }) {
    return ReactionResult(
      success: true,
      message: message,
      myReaction: myReaction,
      reactionSummary: reactionSummary,
      reactionCount: reactionCount,
    );
  }

  factory ReactionResult.failure(String message) {
    return ReactionResult(success: false, message: message);
  }

  factory ReactionResult.fromPayload(Map<String, dynamic> data, {String? message}) {
    return ReactionResult.success(
      message: message ?? 'Reacción actualizada',
      myReaction: data['myReaction']?.toString(),
      reactionSummary: parseReactionSummary(data['reactionSummary']),
      reactionCount: (data['reactionCount'] as num?)?.toInt() ?? 0,
    );
  }
}
