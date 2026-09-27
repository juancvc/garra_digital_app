import 'reaction_type.dart';
import 'wall_comment_model.dart';
import 'wall_post_model.dart';

/// Applies an optimistic reaction change locally.
///
/// - [nextReaction] null → remove current reaction
/// - same as current → treated as remove
/// - different → change (count stays same) or add (count +1)
WallPostModel applyOptimisticReaction(
  WallPostModel post,
  String? nextReaction,
) {
  final summary = Map<String, int>.from(post.reactionSummary);
  var count = post.reactionCount;
  final previous = post.myReaction;

  String? target = nextReaction;
  if (target != null &&
      previous != null &&
      target.toUpperCase() == previous.toUpperCase()) {
    target = null;
  }

  if (previous != null) {
    final key = previous.toUpperCase();
    if (summary.containsKey(key)) {
      summary[key] = (summary[key]! - 1).clamp(0, 1 << 30);
    }
    if (target == null) {
      count = (count - 1).clamp(0, 1 << 30);
    }
  }

  if (target != null) {
    final key = target.toUpperCase();
    if (summary.containsKey(key)) {
      summary[key] = summary[key]! + 1;
    }
    if (previous == null) {
      count += 1;
    }
  }

  return post.copyWith(
    myReaction: target?.toUpperCase(),
    clearMyReaction: target == null,
    reactionSummary: summary,
    reactionCount: count,
  );
}

WallPostModel applyReactionResponse({
  required WallPostModel post,
  required String? myReaction,
  required Map<String, int> reactionSummary,
  required int reactionCount,
}) {
  return post.copyWith(
    myReaction: myReaction,
    clearMyReaction: myReaction == null,
    reactionSummary: parseReactionSummary(reactionSummary),
    reactionCount: reactionCount,
  );
}

/// Optimistic toggle for comment reactions. Same rules as posts:
/// null or the current type removes, another type changes, none adds.
WallCommentModel applyOptimisticCommentReaction(
  WallCommentModel comment,
  String? nextReaction,
) {
  final summary = Map<String, int>.from(comment.reactionSummary);
  var count = comment.reactionCount;
  final previous = comment.myReaction?.toUpperCase();

  var target = nextReaction?.toUpperCase();
  if (target != null && target == previous) target = null;

  if (previous != null) {
    final current = summary[previous] ?? 0;
    if (current > 0) summary[previous] = current - 1;
    if (target == null && count > 0) count -= 1;
  }
  if (target != null) {
    summary[target] = (summary[target] ?? 0) + 1;
    if (previous == null) count += 1;
  }

  return comment.copyWith(
    myReaction: target,
    clearMyReaction: target == null,
    reactionSummary: summary,
    reactionCount: count,
  );
}

/// Applies the server reaction state (source of truth) to a comment.
WallCommentModel applyCommentReactionResponse({
  required WallCommentModel comment,
  required String? myReaction,
  required Map<String, int> reactionSummary,
  required int reactionCount,
}) {
  final normalized = myReaction?.trim().toUpperCase();
  final hasReaction = normalized != null && normalized.isNotEmpty;
  return comment.copyWith(
    myReaction: hasReaction ? normalized : null,
    clearMyReaction: !hasReaction,
    reactionSummary: parseReactionSummary(reactionSummary),
    reactionCount: reactionCount,
  );
}
