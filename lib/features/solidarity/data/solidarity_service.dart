import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/garra_error.dart';

/// Human label (es) for a backend `SolidarityCampaignType` code.
String solidarityTypeLabel(String type) {
  switch (type.toUpperCase()) {
    case 'BLOOD':
      return 'Donaci\u00f3n de sangre';
    case 'FOOD':
      return 'Alimentos';
    case 'SCHOOL_SUPPLIES':
      return '\u00datiles escolares';
    case 'VOLUNTEER':
      return 'Voluntariado';
    case 'EMERGENCY':
      return 'Emergencia';
    default:
      return 'Otra causa';
  }
}

/// Owner-facing lifecycle derived from the backend contract:
/// DRAFT+PENDING without `submittedAt` = borrador; PENDING with
/// `submittedAt` = en revisi\u00f3n; ACTIVE+VERIFIED = publicada; REJECTED =
/// no aprobada (editable and resubmittable); CLOSED/CANCELLED = finalizada.
enum SolidarityOwnerState { draft, inReview, published, rejected, closed }

String solidarityStateLabel(SolidarityOwnerState state) {
  switch (state) {
    case SolidarityOwnerState.draft:
      return 'Borrador';
    case SolidarityOwnerState.inReview:
      return 'En revisi\u00f3n';
    case SolidarityOwnerState.published:
      return 'Publicada';
    case SolidarityOwnerState.rejected:
      return 'No aprobada';
    case SolidarityOwnerState.closed:
      return 'Finalizada';
  }
}

String solidarityStateDescription(SolidarityOwnerState state) {
  switch (state) {
    case SolidarityOwnerState.draft:
      return 'Todav\u00eda no la enviaste a revisi\u00f3n. Solo t\u00fa puedes verla.';
    case SolidarityOwnerState.inReview:
      return 'Garra la est\u00e1 revisando. A\u00fan no es p\u00fablica; revisa su estado aqu\u00ed.';
    case SolidarityOwnerState.published:
      return 'Aprobada por Garra y visible para la comunidad.';
    case SolidarityOwnerState.rejected:
      return 'Garra no la aprob\u00f3. Corr\u00edgela y vuelve a enviarla.';
    case SolidarityOwnerState.closed:
      return 'Esta iniciativa ya finaliz\u00f3.';
  }
}

class SolidarityCampaign {
  SolidarityCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.city,
    this.district,
    this.address,
    this.contactName,
    this.contactPhone,
    this.contactWhatsapp,
    this.evidenceImageUrl,
    this.createdByUsername,
    this.rejectionReason,
    this.submittedAt,
    required this.status,
    required this.verificationStatus,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String city;
  final String? district;
  final String? address;
  final String? contactName;
  final String? contactPhone;
  final String? contactWhatsapp;
  final String? evidenceImageUrl;
  final String? createdByUsername;
  final String? rejectionReason;
  final String? submittedAt;
  final String status;
  final String verificationStatus;

  factory SolidarityCampaign.fromJson(Map<String, dynamic> json) {
    return SolidarityCampaign(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'OTHER',
      city: json['city']?.toString() ?? '',
      district: _text(json['district']),
      address: _text(json['address']),
      contactName: _text(json['contactName']),
      contactPhone: _text(json['contactPhone']),
      contactWhatsapp: _text(json['contactWhatsapp']),
      evidenceImageUrl: _text(json['evidenceImageUrl']),
      createdByUsername: _text(json['createdByUsername']),
      rejectionReason: _text(json['rejectionReason']),
      submittedAt: _text(json['submittedAt']),
      status: json['status']?.toString() ?? 'DRAFT',
      verificationStatus: json['verificationStatus']?.toString() ?? 'PENDING',
    );
  }

  bool get isVerified => verificationStatus == 'VERIFIED';

  /// Public = what the backend lists for everyone (ACTIVE + VERIFIED).
  bool get isPublic => isVerified && status.toUpperCase() == 'ACTIVE';

  SolidarityOwnerState get ownerState {
    final s = status.toUpperCase();
    final v = verificationStatus.toUpperCase();
    if (s == 'CLOSED' || s == 'CANCELLED') return SolidarityOwnerState.closed;
    if (v == 'VERIFIED') {
      return s == 'ACTIVE'
          ? SolidarityOwnerState.published
          : SolidarityOwnerState.closed;
    }
    if (v == 'REJECTED') return SolidarityOwnerState.rejected;
    if (submittedAt != null) return SolidarityOwnerState.inReview;
    return SolidarityOwnerState.draft;
  }

  /// The backend only accepts PUT/submit for drafts and rejected campaigns.
  bool get canEdit =>
      ownerState == SolidarityOwnerState.draft ||
      ownerState == SolidarityOwnerState.rejected;

  bool get hasContactChannel =>
      (contactWhatsapp?.isNotEmpty ?? false) ||
      (contactPhone?.isNotEmpty ?? false);

  static String? _text(Object? value) {
    final t = value?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }
}

/// Spanish copy for a failed Solidaria write. Known backend business errors
/// (English) are translated; nothing raw reaches the user.
String solidarityActionErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final raw = data is Map ? data['message']?.toString() ?? '' : '';
    final lower = raw.toLowerCase();
    if (lower.contains('not campaign owner')) {
      return 'Solo quien cre\u00f3 la iniciativa puede modificarla.';
    }
    if (lower.contains('pending review')) {
      return 'Tu iniciativa ya est\u00e1 en revisi\u00f3n. Espera la respuesta de Garra.';
    }
    if (lower.contains('verified')) {
      return 'Esta iniciativa ya fue aprobada y publicada; no se puede editar.';
    }
    if (lower.contains('closed')) {
      return 'Esta iniciativa ya finaliz\u00f3.';
    }
    if (lower.contains('media') || lower.contains('asset')) {
      return 'La foto no est\u00e1 lista. Qu\u00edtala o vuelve a subirla.';
    }
    final code = error.response?.statusCode;
    if (code == 400 || code == 422) {
      return 'Revisa los datos de la iniciativa e int\u00e9ntalo nuevamente.';
    }
    final kind = classifyDioError(error).kind;
    if (kind == GarraErrorKind.offline || kind == GarraErrorKind.timeout) {
      return 'Parece que est\u00e1s sin conexi\u00f3n. Tus datos siguen aqu\u00ed; '
          'int\u00e9ntalo nuevamente.';
    }
    if (kind == GarraErrorKind.session) {
      return 'Tu sesi\u00f3n expir\u00f3. Vuelve a iniciar sesi\u00f3n.';
    }
  }
  return 'No pudimos enviar la iniciativa. Tus datos siguen aqu\u00ed; '
      'int\u00e9ntalo nuevamente.';
}

/// True when the backend reports the campaign does not exist for this
/// viewer (non-public campaigns are 404 for everyone but owner/staff).
bool isSolidarityNotFound(Object error) =>
    error is DioException && error.response?.statusCode == 404;

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

  /// Owner's own campaigns in every state (`GET /campaigns/me`).
  Future<List<SolidarityCampaign>> listMine() async {
    final response = await _dio.get('/solidarity/campaigns/me');
    final List data = response.data['data'] ?? [];
    return data
        .map((e) => SolidarityCampaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Owner edit of a draft/rejected campaign (`PUT /campaigns/{id}`).
  Future<SolidarityCampaign> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.put('/solidarity/campaigns/$id', data: body);
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
