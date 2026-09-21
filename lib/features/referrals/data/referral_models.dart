class ReferralCampaignSummary {
  const ReferralCampaignSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.inviterRewardPoints,
    required this.refereeRewardPoints,
    required this.qualificationAction,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String name;
  final String status;
  final int inviterRewardPoints;
  final int refereeRewardPoints;
  final String qualificationAction;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get isActive => status == 'ACTIVE';

  factory ReferralCampaignSummary.fromJson(Map<String, dynamic> json) {
    return ReferralCampaignSummary(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      inviterRewardPoints: (json['inviterRewardPoints'] as num?)?.toInt() ?? 0,
      refereeRewardPoints: (json['refereeRewardPoints'] as num?)?.toInt() ?? 0,
      qualificationAction: json['qualificationAction'] as String? ?? '',
      startsAt: json['startsAt'] == null
          ? null
          : DateTime.tryParse(json['startsAt'].toString()),
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.tryParse(json['endsAt'].toString()),
    );
  }
}

class ReferralMe {
  const ReferralMe({
    required this.myCode,
    this.activeCampaign,
    required this.qualifiedCount,
    required this.pendingCount,
    required this.pointsEarnedFromReferrals,
  });

  final String myCode;
  final ReferralCampaignSummary? activeCampaign;
  final int qualifiedCount;
  final int pendingCount;
  final int pointsEarnedFromReferrals;

  factory ReferralMe.fromJson(Map<String, dynamic> json) {
    return ReferralMe(
      myCode: json['myCode'] as String? ?? '',
      activeCampaign: json['activeCampaign'] == null
          ? null
          : ReferralCampaignSummary.fromJson(
              Map<String, dynamic>.from(json['activeCampaign'] as Map),
            ),
      qualifiedCount: (json['qualifiedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      pointsEarnedFromReferrals:
          (json['pointsEarnedFromReferrals'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReferralClaimResult {
  const ReferralClaimResult({
    required this.attributionId,
    required this.status,
    required this.message,
  });

  final String attributionId;
  final String status;
  final String message;

  factory ReferralClaimResult.fromJson(Map<String, dynamic> json) {
    return ReferralClaimResult(
      attributionId: json['attributionId']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? 'Invitación registrada',
    );
  }
}

/// Maps backend / Dio claim errors to friendly Spanish copy.
String referralClaimErrorMessage(Object error) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('propio código') || raw.contains('own')) {
    return 'No puedes usar tu propio código';
  }
  if (raw.contains('ya tienes') || raw.contains('atribuida')) {
    return 'Ya registraste una invitación';
  }
  if (raw.contains('ventana')) {
    return 'Fuera del plazo para usar un código';
  }
  if (raw.contains('no hay campaña') || raw.contains('campaña')) {
    return 'No hay campaña de referidos activa';
  }
  if (raw.contains('inválido') || raw.contains('invalid')) {
    return 'Código de invitación inválido';
  }
  return 'No pudimos registrar el código. Intenta de nuevo.';
}
