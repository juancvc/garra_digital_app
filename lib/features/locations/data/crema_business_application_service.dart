import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

enum CremaBusinessApplicationStatus {
  draft,
  pending,
  verified,
  rejected;

  static CremaBusinessApplicationStatus fromApi(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING':
        return CremaBusinessApplicationStatus.pending;
      case 'VERIFIED':
        return CremaBusinessApplicationStatus.verified;
      case 'REJECTED':
        return CremaBusinessApplicationStatus.rejected;
      default:
        return CremaBusinessApplicationStatus.draft;
    }
  }

  String get label {
    switch (this) {
      case CremaBusinessApplicationStatus.draft:
        return 'Borrador';
      case CremaBusinessApplicationStatus.pending:
        return 'En revisión';
      case CremaBusinessApplicationStatus.verified:
        return 'Verificado';
      case CremaBusinessApplicationStatus.rejected:
        return 'Rechazado';
    }
  }
}

class CremaBusinessApplication {
  const CremaBusinessApplication({
    required this.id,
    required this.businessName,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.description,
    this.phone,
    this.whatsapp,
    this.instagram,
    this.rejectionReason,
    this.cremaPointId,
  });

  final String id;
  final String businessName;
  final String? description;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? whatsapp;
  final String? instagram;
  final CremaBusinessApplicationStatus status;
  final String? rejectionReason;
  final String? cremaPointId;

  factory CremaBusinessApplication.fromJson(Map<String, dynamic> json) {
    return CremaBusinessApplication(
      id: json['id'].toString(),
      businessName: json['businessName']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      instagram: json['instagram']?.toString(),
      status: CremaBusinessApplicationStatus.fromApi(json['status']?.toString()),
      rejectionReason: json['rejectionReason']?.toString(),
      cremaPointId: json['cremaPointId']?.toString(),
    );
  }
}

class CremaBusinessApplicationService {
  CremaBusinessApplicationService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<CremaBusinessApplication>> listMine() async {
    final response = await _dio.get('/locations/business-applications/me');
    final data = response.data['data'];
    final list = data is List ? data : const [];
    return list
        .map((e) => CremaBusinessApplication.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<CremaBusinessApplication> create(Map<String, dynamic> body) async {
    final response = await _dio.post(
      '/locations/business-applications',
      data: body,
    );
    return CremaBusinessApplication.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<CremaBusinessApplication> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch(
      '/locations/business-applications/$id',
      data: body,
    );
    return CremaBusinessApplication.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<CremaBusinessApplication> submit(String id) async {
    final response = await _dio.post('/locations/business-applications/$id/submit');
    return CremaBusinessApplication.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }
}
