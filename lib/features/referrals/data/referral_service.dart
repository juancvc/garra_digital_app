import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'referral_models.dart';

class ReferralService {
  ReferralService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<ReferralMe> me() async {
    final response = await _dio.get('/referrals/me');
    final data = response.data['data'];
    return ReferralMe.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ReferralClaimResult> claim(String code) async {
    try {
      final response = await _dio.post(
        '/referrals/claim',
        data: {'code': code.trim()},
      );
      final data = response.data['data'];
      return ReferralClaimResult.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.response!.data['error'])?.toString()
          : null;
      throw Exception(msg ?? e.message ?? 'claim_failed');
    }
  }
}
