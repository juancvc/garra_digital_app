import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'garra_football_models.dart';

/// SONIC_01B: which layer failed when Centro Garra could not load. The UI keeps
/// friendly copy; logs (debug only) name the layer. Never tokens or payloads.
enum FootballFailureLayer { appNetwork, auth, backend, backendContract, other }

extension FootballFailureLayerCode on FootballFailureLayer {
  String get code => switch (this) {
    FootballFailureLayer.appNetwork => 'APP_NETWORK',
    FootballFailureLayer.auth => 'AUTH',
    FootballFailureLayer.backend => 'BACKEND',
    FootballFailureLayer.backendContract => 'BACKEND_CONTRACT',
    FootballFailureLayer.other => 'OTHER',
  };
}

FootballFailureLayer footballFailureLayer(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return FootballFailureLayer.appNetwork;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 401 || status == 403) return FootballFailureLayer.auth;
        if (status >= 500) return FootballFailureLayer.backend;
        return FootballFailureLayer.backendContract;
      default:
        return FootballFailureLayer.other;
    }
  }
  if (error is FormatException || error is TypeError) {
    return FootballFailureLayer.backendContract;
  }
  return FootballFailureLayer.other;
}

/// Request failed before a usable answer: method/path/status/type only.
void logFootballFailure(String operation, Object error) {
  if (!kDebugMode) return;
  final layer = footballFailureLayer(error);
  if (error is DioException) {
    debugPrint('[FOOTBALL][APP] operation=$operation layer=${layer.code} '
        'path=${error.requestOptions.path} status=${error.response?.statusCode ?? 'none'} '
        'type=${error.type.name}');
  } else {
    debugPrint('[FOOTBALL][APP] operation=$operation layer=${layer.code} '
        'error=${error.runtimeType}');
  }
}

/// The API answered, but some or all sources failed (reason = backend layer).
void logFootballAnswer(String operation, FootballPage<dynamic> page) {
  if (!kDebugMode) return;
  if (!page.unavailable && !page.partial && !page.stale) return;
  debugPrint('[FOOTBALL][API] operation=$operation items=${page.items.length} '
      'unavailable=${page.unavailable} partial=${page.partial} stale=${page.stale} '
      'reason=${page.reason ?? 'none'}');
}
