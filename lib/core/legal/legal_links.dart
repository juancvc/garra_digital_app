import 'package:flutter/material.dart';

import '../config/api_config.dart';
import 'garra_legal_documents.dart';
import 'garra_legal_modal.dart';

/// Absolute URL of a backend legal page (`/legal/privacy`, `/legal/terms`,
/// `/legal/community`). Kept for deep links / store listings; in-app UI uses
/// [showGarraLegalDocumentModal] instead of opening a browser.
Uri resolveLegalUri(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.isEmpty) {
    return Uri.parse(ApiConfig.baseUrl.replaceAll('/api/v1', '/legal/privacy'));
  }
  if (pathOrUrl.startsWith('http')) return Uri.parse(pathOrUrl);
  final root = ApiConfig.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
  return Uri.parse('$root$pathOrUrl');
}

GarraLegalDocument? legalDocumentForPath(String? pathOrUrl) {
  final path = pathOrUrl ?? '';
  if (path.contains('privacy')) return GarraLegalDocument.privacy;
  if (path.contains('terms')) return GarraLegalDocument.terms;
  if (path.contains('community')) return GarraLegalDocument.community;
  return null;
}

/// Shows community guidelines inside Garra (never opens an external browser).
Future<bool> openCommunityGuidelines(BuildContext context) async {
  await showGarraLegalDocumentModal(context, GarraLegalDocument.community);
  return true;
}
