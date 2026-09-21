import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../marketplace/data/marketplace_media_service.dart';

class SponsoredCard {
  const SponsoredCard({
    required this.activationId,
    required this.campaignId,
    required this.sponsorName,
    this.sponsorSlug,
    this.logoUrl,
    required this.headline,
    this.body,
    this.ctaLabel,
    this.ctaUrl,
    required this.label,
    this.matchId,
  });

  final String activationId;
  final String campaignId;
  final String sponsorName;
  final String? sponsorSlug;
  final String? logoUrl;
  final String headline;
  final String? body;
  final String? ctaLabel;
  final String? ctaUrl;
  final String label;
  final String? matchId;

  factory SponsoredCard.fromJson(Map<String, dynamic> json) {
    return SponsoredCard(
      activationId: json['activationId']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      sponsorName: json['sponsorName'] as String? ?? '',
      sponsorSlug: json['sponsorSlug']?.toString(),
      logoUrl: json['logoUrl'] as String?,
      headline: json['headline'] as String? ?? '',
      body: json['body'] as String?,
      ctaLabel: json['ctaLabel'] as String?,
      ctaUrl: json['ctaUrl'] as String?,
      label: json['label'] as String? ??
          (json['sponsorName'] != null
              ? 'Patrocinado por ${json['sponsorName']}'
              : 'Patrocinado'),
      matchId: json['matchId']?.toString(),
    );
  }
}

class SponsorService {
  SponsorService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<SponsoredCard?> getMatchdayCard({String? matchId}) async {
    final response = await _dio.get(
      '/sponsors/matchday-card',
      queryParameters: {
        if (matchId != null && matchId.isNotEmpty) 'matchId': matchId,
      },
    );
    final data = response.data['data'];
    if (data is! Map) return null;
    return SponsoredCard.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> trackImpression(String activationId) async {
    try {
      await _dio.post(
        '/sponsors/activations/$activationId/impression',
        data: {'sessionId': MarketplaceMediaService.analyticsSessionId()},
      );
    } catch (_) {
      // Non-blocking analytics.
    }
  }

  Future<void> trackOpen(String activationId) async {
    try {
      await _dio.post(
        '/sponsors/activations/$activationId/open',
        data: {'sessionId': MarketplaceMediaService.analyticsSessionId()},
      );
    } catch (_) {
      // Non-blocking analytics.
    }
  }
}

/// Returns true only for https URLs with a host.
bool isSafeHttpsUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  if (uri.scheme.toLowerCase() != 'https') return false;
  if (uri.host.isEmpty) return false;
  final lower = url.toLowerCase();
  if (lower.startsWith('javascript:') ||
      lower.startsWith('data:') ||
      lower.startsWith('file:')) {
    return false;
  }
  return true;
}
