class MatchdaySummary {
  const MatchdaySummary({
    required this.match,
    required this.pollaState,
    required this.openPolls,
    required this.mvpOpen,
    this.mvpPollId,
  });

  final MatchdayMatchSummary match;
  final String pollaState;
  final List<MatchdayPollSummary> openPolls;
  final bool mvpOpen;
  final String? mvpPollId;

  factory MatchdaySummary.fromJson(Map<String, dynamic> json) {
    final rawPolls = json['openPolls'] as List? ?? const [];
    final polls = rawPolls
        .map(
          (e) => MatchdayPollSummary.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final mvpFromFlag = json['mvpOpen'] as bool? ??
        json['mvpAvailable'] as bool? ??
        false;
    String? mvpPollId = json['mvpPollId']?.toString();
    mvpPollId ??= polls.where((p) => p.type == 'MVP').map((p) => p.id).firstOrNull;

    return MatchdaySummary(
      match: MatchdayMatchSummary.fromJson(
        Map<String, dynamic>.from(json['match'] as Map? ?? const {}),
      ),
      pollaState: json['pollaState']?.toString() ?? 'NOT_OPEN',
      openPolls: polls,
      mvpOpen: mvpFromFlag || mvpPollId != null,
      mvpPollId: mvpPollId,
    );
  }
}

class MatchdayMatchSummary {
  const MatchdayMatchSummary({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchDateTime,
    required this.stadium,
    required this.competition,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.predictionClosesAt,
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime matchDateTime;
  final String stadium;
  final String competition;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final DateTime? predictionClosesAt;

  factory MatchdayMatchSummary.fromJson(Map<String, dynamic> json) {
    return MatchdayMatchSummary(
      id: json['id'].toString(),
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      matchDateTime: DateTime.tryParse(json['matchDateTime']?.toString() ?? '') ??
          DateTime.now(),
      stadium: json['stadium'] as String? ?? '',
      competition: json['competition'] as String? ?? '',
      status: json['status']?.toString() ?? '',
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
      predictionClosesAt:
          DateTime.tryParse(json['predictionClosesAt']?.toString() ?? ''),
    );
  }
}

class MatchdayPollSummary {
  const MatchdayPollSummary({
    required this.id,
    required this.question,
    required this.type,
    required this.status,
  });

  final String id;
  final String question;
  final String type;
  final String status;

  factory MatchdayPollSummary.fromJson(Map<String, dynamic> json) {
    return MatchdayPollSummary(
      id: json['id'].toString(),
      question: json['question'] as String? ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      status: json['status']?.toString() ?? 'DRAFT',
    );
  }
}

class MatchPoll {
  const MatchPoll({
    required this.id,
    required this.matchId,
    required this.question,
    required this.type,
    required this.status,
    this.opensAt,
    this.closesAt,
    required this.voteCount,
    required this.options,
  });

  final String id;
  final String matchId;
  final String question;
  final String type;
  final String status;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final int voteCount;
  final List<MatchPollOption> options;

  bool get isOpen => status == 'OPEN';
  bool get isClosed => status == 'CLOSED';
  bool get isMvp => type == 'MVP';

  factory MatchPoll.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? const [];
    return MatchPoll(
      id: json['id'].toString(),
      matchId: json['matchId'].toString(),
      question: json['question'] as String? ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      status: json['status']?.toString() ?? 'DRAFT',
      opensAt: DateTime.tryParse(json['opensAt']?.toString() ?? ''),
      closesAt: DateTime.tryParse(json['closesAt']?.toString() ?? ''),
      voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
      options: rawOptions
          .map(
            (e) => MatchPollOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class MatchPollOption {
  const MatchPollOption({
    required this.id,
    required this.displayName,
    this.shirtNumber,
    this.imageUrl,
    required this.sortOrder,
    required this.voteCount,
  });

  final String id;
  final String displayName;
  final int? shirtNumber;
  final String? imageUrl;
  final int sortOrder;
  final int voteCount;

  factory MatchPollOption.fromJson(Map<String, dynamic> json) {
    return MatchPollOption(
      id: (json['id'] ?? json['optionId']).toString(),
      displayName: json['displayName'] as String? ?? '',
      shirtNumber: (json['shirtNumber'] as num?)?.toInt(),
      imageUrl: json['imageUrl'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MatchPollResults {
  const MatchPollResults({
    required this.pollId,
    required this.totalVotes,
    this.myVoteOptionId,
    required this.options,
  });

  final String pollId;
  final int totalVotes;
  final String? myVoteOptionId;
  final List<MatchPollOptionResult> options;

  factory MatchPollResults.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? const [];
    return MatchPollResults(
      pollId: json['pollId'].toString(),
      totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
      myVoteOptionId: json['myVoteOptionId']?.toString(),
      options: rawOptions
          .map(
            (e) => MatchPollOptionResult.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class MatchPollOptionResult {
  const MatchPollOptionResult({
    required this.optionId,
    required this.displayName,
    this.shirtNumber,
    this.imageUrl,
    required this.sortOrder,
    required this.voteCount,
    required this.percentage,
  });

  final String optionId;
  final String displayName;
  final int? shirtNumber;
  final String? imageUrl;
  final int sortOrder;
  final int voteCount;
  final int percentage;

  factory MatchPollOptionResult.fromJson(Map<String, dynamic> json) {
    return MatchPollOptionResult(
      optionId: (json['optionId'] ?? json['id']).toString(),
      displayName: json['displayName'] as String? ?? '',
      shirtNumber: (json['shirtNumber'] as num?)?.toInt(),
      imageUrl: json['imageUrl'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
    );
  }
}
