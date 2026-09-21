class ReportWallPostRequest {
  const ReportWallPostRequest({
    required this.category,
    this.reason,
  });

  final String category;
  final String? reason;

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      if (reason != null && reason!.isNotEmpty) 'reason': reason,
    };
  }
}