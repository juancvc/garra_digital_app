import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';

/// PLAY-02: channels accepted by `POST /legal/acceptance`.
enum LegalAcceptanceChannel {
  signup('SIGNUP'),
  onboarding('ONBOARDING'),
  updatePrompt('UPDATE_PROMPT');

  const LegalAcceptanceChannel(this.code);
  final String code;
}

/// Current legal versions plus whether this user accepted them.
class LegalAcceptanceStatus {
  const LegalAcceptanceStatus({
    required this.termsVersion,
    required this.privacyVersion,
    required this.termsPath,
    required this.privacyPath,
    required this.accepted,
    this.acceptedAt,
  });

  factory LegalAcceptanceStatus.fromJson(Map<String, dynamic> json) {
    return LegalAcceptanceStatus(
      termsVersion: json['termsVersion']?.toString() ?? '',
      privacyVersion: json['privacyVersion']?.toString() ?? '',
      termsPath: json['termsPath']?.toString() ?? '/legal/terms',
      privacyPath: json['privacyPath']?.toString() ?? '/legal/privacy',
      accepted: json['accepted'] == true,
      acceptedAt: DateTime.tryParse(json['acceptedAt']?.toString() ?? ''),
    );
  }

  final String termsVersion;
  final String privacyVersion;
  final String termsPath;
  final String privacyPath;
  final bool accepted;
  final DateTime? acceptedAt;
}

/// `GET/POST /legal/acceptance`. The server stamps `acceptedAt`; the client
/// only echoes the versions it showed so a stale screen cannot accept a newer
/// text (409).
class LegalAcceptanceService {
  LegalAcceptanceService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<LegalAcceptanceStatus> status() async {
    final response = await _dio.get('/legal/acceptance');
    return LegalAcceptanceStatus.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  /// Accepts the current versions (fetched first when not given).
  Future<LegalAcceptanceStatus> accept(
    LegalAcceptanceChannel channel, {
    LegalAcceptanceStatus? current,
  }) async {
    final versions = current ?? await status();
    final response = await _dio.post(
      '/legal/acceptance',
      data: {
        'termsVersion': versions.termsVersion,
        'privacyVersion': versions.privacyVersion,
        'channel': channel.code,
      },
    );
    return LegalAcceptanceStatus.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }
}

final legalAcceptanceServiceProvider = Provider<LegalAcceptanceService>(
  (ref) => LegalAcceptanceService(),
);
