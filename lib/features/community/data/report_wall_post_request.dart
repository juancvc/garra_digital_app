class ReportWallPostRequest {
  const ReportWallPostRequest({
    required this.reason,
  });

  final String reason;

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
    };
  }
}