import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

class SolidarityCampaign {
  SolidarityCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.city,
    this.district,
    this.contactWhatsapp,
    this.evidenceImageUrl,
    required this.status,
    required this.verificationStatus,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String city;
  final String? district;
  final String? contactWhatsapp;
  final String? evidenceImageUrl;
  final String status;
  final String verificationStatus;

  factory SolidarityCampaign.fromJson(Map<String, dynamic> json) {
    return SolidarityCampaign(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'OTHER',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString(),
      contactWhatsapp: json['contactWhatsapp']?.toString(),
      evidenceImageUrl: json['evidenceImageUrl']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      verificationStatus: json['verificationStatus']?.toString() ?? 'PENDING',
    );
  }

  bool get isVerified => verificationStatus == 'VERIFIED';
}

class SolidarityService {
  SolidarityService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<SolidarityCampaign>> listPublic({String? type}) async {
    final response = await _dio.get(
      '/solidarity/campaigns',
      queryParameters: type == null ? null : {'type': type},
    );
    final List data = response.data['data'] ?? [];
    return data
        .map((e) => SolidarityCampaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SolidarityCampaign> get(String id) async {
    final response = await _dio.get('/solidarity/campaigns/$id');
    return SolidarityCampaign.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<SolidarityCampaign> create(Map<String, dynamic> body) async {
    final response = await _dio.post('/solidarity/campaigns', data: body);
    return SolidarityCampaign.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<SolidarityCampaign> submit(String id) async {
    final response = await _dio.post('/solidarity/campaigns/$id/submit');
    return SolidarityCampaign.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }
}
