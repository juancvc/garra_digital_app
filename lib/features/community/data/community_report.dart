/// MODERATION_11: platform reports (post, comment, profile).
library;

/// What is being reported. [apiValue] matches the backend `targetType`.
enum GarraReportTarget {
  post('POST'),
  comment('COMMENT'),
  profile('PROFILE');

  const GarraReportTarget(this.apiValue);

  final String apiValue;
}

/// One entry of the report reason catalog. [code] is the backend value.
class GarraReportReason {
  const GarraReportReason(this.code, this.label);

  final String code;
  final String label;
}

/// Reason catalog shown in the report sheet (backend `CommunityReportCategory`).
const garraReportReasons = <GarraReportReason>[
  GarraReportReason('SPAM', 'Spam'),
  GarraReportReason('INAPPROPRIATE_CONTENT', 'Contenido no apropiado'),
  GarraReportReason('HARASSMENT', 'Acoso u hostigamiento'),
  GarraReportReason('VIOLENCE', 'Violencia o amenazas'),
  GarraReportReason('HATE', 'Odio o discriminaci\u00f3n'),
  GarraReportReason('TERRORISM_OR_EXTREMISM', 'Terrorismo o extremismo'),
  GarraReportReason('FRAUD', 'Estafa o fraude'),
  GarraReportReason('IMPERSONATION', 'Suplantaci\u00f3n de identidad'),
  GarraReportReason('PERSONAL_INFORMATION', 'Informaci\u00f3n personal'),
  GarraReportReason('OTHER', 'Otro'),
];

/// Backend limit for the optional detail.
const garraReportDetailMaxLength = 500;

const garraReportThanksMessage = 'Gracias. Revisaremos tu denuncia.';
const garraReportFallbackError =
    'No pudimos enviar tu denuncia. Int\u00e9ntalo de nuevo.';

class ReportSubmitResult {
  const ReportSubmitResult._(this.success, this.message);

  factory ReportSubmitResult.success([String? message]) =>
      ReportSubmitResult._(true, message ?? garraReportThanksMessage);

  factory ReportSubmitResult.failure(String message) =>
      ReportSubmitResult._(false, message);

  final bool success;
  final String message;
}
