class RewardOffer {
  const RewardOffer({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.providerType,
    required this.providerLabel,
    this.providerName,
    required this.sponsored,
    required this.status,
    required this.pointsCost,
    required this.stockMode,
    this.stockRemaining,
    required this.available,
    required this.maxRedemptionsPerFan,
    required this.myRedemptionCount,
    required this.canRedeem,
    this.ineligibilityReason,
    this.startsAt,
    this.endsAt,
    this.imageUrl,
    this.terms,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String providerType;
  final String providerLabel;
  final String? providerName;
  final bool sponsored;
  final String status;
  final int pointsCost;
  final String stockMode;
  final int? stockRemaining;
  final bool available;
  final int maxRedemptionsPerFan;
  final int myRedemptionCount;
  final bool canRedeem;
  final String? ineligibilityReason;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? imageUrl;
  final String? terms;

  factory RewardOffer.fromJson(Map<String, dynamic> json) {
    return RewardOffer(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      providerType: json['providerType'] as String? ?? 'PLATFORM',
      providerLabel: json['providerLabel'] as String? ?? 'Beneficio Garra',
      providerName: json['providerName'] as String?,
      sponsored: json['sponsored'] as bool? ?? false,
      status: json['status'] as String? ?? '',
      pointsCost: (json['pointsCost'] as num?)?.toInt() ?? 0,
      stockMode: json['stockMode'] as String? ?? 'UNLIMITED',
      stockRemaining: (json['stockRemaining'] as num?)?.toInt(),
      available: json['available'] as bool? ?? false,
      maxRedemptionsPerFan: (json['maxRedemptionsPerFan'] as num?)?.toInt() ?? 1,
      myRedemptionCount: (json['myRedemptionCount'] as num?)?.toInt() ?? 0,
      canRedeem: json['canRedeem'] as bool? ?? false,
      ineligibilityReason: json['ineligibilityReason'] as String?,
      startsAt: json['startsAt'] == null
          ? null
          : DateTime.tryParse(json['startsAt'].toString()),
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.tryParse(json['endsAt'].toString()),
      imageUrl: json['imageUrl'] as String?,
      terms: json['terms'] as String?,
    );
  }
}

class RewardRedemption {
  const RewardRedemption({
    required this.id,
    required this.rewardSlug,
    required this.rewardTitle,
    required this.providerLabel,
    required this.pointsSpent,
    required this.status,
    required this.redemptionCode,
    this.createdAt,
    this.expiresAt,
    this.redeemedAt,
  });

  final String id;
  final String rewardSlug;
  final String rewardTitle;
  final String providerLabel;
  final int pointsSpent;
  final String status;
  final String redemptionCode;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? redeemedAt;

  String get statusLabelEs => switch (status) {
        'ISSUED' => 'Disponible',
        'REDEEMED' => 'Canjeado',
        'EXPIRED' => 'Expirado',
        'CANCELLED' => 'Cancelado',
        _ => status,
      };

  factory RewardRedemption.fromJson(Map<String, dynamic> json) {
    return RewardRedemption(
      id: json['id']?.toString() ?? '',
      rewardSlug: json['rewardSlug'] as String? ?? '',
      rewardTitle: json['rewardTitle'] as String? ?? '',
      providerLabel: json['providerLabel'] as String? ?? '',
      pointsSpent: (json['pointsSpent'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      redemptionCode: json['redemptionCode'] as String? ?? '',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'].toString()),
      redeemedAt: json['redeemedAt'] == null
          ? null
          : DateTime.tryParse(json['redeemedAt'].toString()),
    );
  }
}
