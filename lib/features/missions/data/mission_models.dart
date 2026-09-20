class MissionModel {
  const MissionModel({
    required this.id,
    required this.title,
    this.description,
    required this.scopeType,
    this.scopeReferenceId,
    required this.status,
    this.startsAt,
    this.endsAt,
    required this.rewardPoints,
    this.countsForStreak = false,
    required this.completedSteps,
    required this.totalSteps,
    required this.completed,
    this.completedAt,
    this.steps = const [],
  });

  final String id;
  final String title;
  final String? description;
  final String scopeType;
  final String? scopeReferenceId;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int rewardPoints;
  final bool countsForStreak;
  final int completedSteps;
  final int totalSteps;
  final bool completed;
  final DateTime? completedAt;
  final List<MissionStepModel> steps;

  double get progressFraction {
    if (totalSteps <= 0) return completed ? 1.0 : 0.0;
    return (completedSteps / totalSteps).clamp(0.0, 1.0);
  }

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List? ?? const [];
    return MissionModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      scopeType: json['scopeType']?.toString() ?? 'GLOBAL',
      scopeReferenceId: json['scopeReferenceId']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      startsAt: _parseDateTime(json['startsAt']),
      endsAt: _parseDateTime(json['endsAt']),
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      countsForStreak: json['countsForStreak'] as bool? ?? false,
      completedSteps: (json['completedSteps'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      completedAt: _parseDateTime(json['completedAt']),
      steps: rawSteps
          .map(
            (e) => MissionStepModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class MissionStepModel {
  const MissionStepModel({
    required this.stepId,
    required this.actionType,
    required this.title,
    required this.requiredCount,
    required this.currentCount,
    required this.completed,
    required this.sortOrder,
  });

  final String stepId;
  final String actionType;
  final String title;
  final int requiredCount;
  final int currentCount;
  final bool completed;
  final int sortOrder;

  factory MissionStepModel.fromJson(Map<String, dynamic> json) {
    return MissionStepModel(
      stepId: (json['stepId'] ?? json['id'])?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      requiredCount: (json['requiredCount'] as num?)?.toInt() ?? 1,
      currentCount: (json['currentCount'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.best,
  });

  final int current;
  final int best;

  bool get isActive => current > 0;

  factory StreakSummary.fromJson(Map<String, dynamic> json) {
    return StreakSummary(
      current: (json['current'] as num?)?.toInt() ?? 0,
      best: (json['best'] as num?)?.toInt() ?? 0,
    );
  }
}
