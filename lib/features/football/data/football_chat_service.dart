import 'package:dio/dio.dart';
import 'package:garra_digital_app/core/network/dio_client.dart';
import 'package:garra_digital_app/core/network/garra_error.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/community/data/community_report.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/community/data/report_wall_post_request.dart';

import 'garra_football_models.dart';

/// SONIC_06: room of the Chat Futbolero. GENERAL (Centro Garra) or MATCH:{providerFixtureId}
/// ("Hablar del partido"). One chat domain; rooms never mix messages.
class FootballChatContext {
  const FootballChatContext._(this.matchId);
  const FootballChatContext.general() : matchId = null;
  const FootballChatContext.match(int this.matchId);

  final int? matchId;

  bool get isMatch => matchId != null;

  /// Wire value for the backend `context` parameter; null for GENERAL (SONIC_03 compatible).
  String? get wire => matchId == null ? null : 'MATCH:$matchId';

  /// Stable key (one poller per room, request tags).
  String get key => wire ?? 'GENERAL';

  static FootballChatContext? tryMatch(int? id) =>
      id == null || id <= 0 ? null : FootballChatContext._(id);

  @override
  bool operator ==(Object other) => other is FootballChatContext && other.matchId == matchId;

  @override
  int get hashCode => matchId.hashCode;
}

class FootballChatReplyPreview {
  const FootballChatReplyPreview({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.preview,
    this.unavailable = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String preview;
  final bool unavailable;

  factory FootballChatReplyPreview.fromJson(Map<String, dynamic> json) =>
      FootballChatReplyPreview(
        id: json['id']?.toString() ?? '',
        authorId: json['authorId']?.toString() ?? '',
        authorName: json['authorName']?.toString() ?? '',
        preview: json['preview']?.toString() ?? '',
        unavailable: json['unavailable'] == true,
      );
}

class FootballChatSticker {
  const FootballChatSticker({
    required this.id,
    required this.name,
    required this.category,
    required this.glyph,
    this.assetKey,
  });

  final String id;
  final String name;
  final String category;
  final String glyph;
  final String? assetKey;

  factory FootballChatSticker.fromJson(Map<String, dynamic> json) =>
      FootballChatSticker(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        glyph: json['glyph']?.toString() ?? '',
        assetKey: json['assetKey']?.toString(),
      );
}

class FootballChatStickerCatalog {
  const FootballChatStickerCatalog({this.items = const []});
  final List<FootballChatSticker> items;

  factory FootballChatStickerCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return FootballChatStickerCatalog(
      items: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(FootballChatSticker.fromJson)
              .where((s) => s.id.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

class FootballChatMessage {
  const FootballChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    required this.body,
    required this.createdAt,
    this.contextType = 'GENERAL',
    this.contextId,
    this.replyTo,
    this.reactions = const [],
    this.messageType = 'TEXT',
    this.stickerId,
    this.sticker,
  });
  final String id;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String body;
  final DateTime? createdAt;
  final String contextType;
  final String? contextId;
  final FootballChatReplyPreview? replyTo;
  final List<ChatMessageReactionSummary> reactions;
  final String messageType;
  final String? stickerId;
  final FootballChatSticker? sticker;

  bool get isSticker => messageType == 'STICKER';

  String get reactionSignature => chatReactionSignature(reactions);

  FootballChatMessage copyWith({
    List<ChatMessageReactionSummary>? reactions,
  }) =>
      FootballChatMessage(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorUsername: authorUsername,
        body: body,
        createdAt: createdAt,
        contextType: contextType,
        contextId: contextId,
        replyTo: replyTo,
        reactions: reactions ?? this.reactions,
        messageType: messageType,
        stickerId: stickerId,
        sticker: sticker,
      );

  factory FootballChatMessage.fromJson(Map<String, dynamic> json) {
    final replyRaw = json['replyTo'];
    final stickerRaw = json['sticker'];
    return FootballChatMessage(
      id: json['id']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Hincha',
      authorUsername: json['authorUsername']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc(),
      contextType: json['contextType']?.toString() ?? 'GENERAL',
      contextId: json['contextId']?.toString(),
      replyTo: replyRaw is Map<String, dynamic>
          ? FootballChatReplyPreview.fromJson(replyRaw)
          : null,
      reactions: parseChatReactions(json['reactions']),
      messageType: json['messageType']?.toString() ?? 'TEXT',
      stickerId: json['stickerId']?.toString(),
      sticker: stickerRaw is Map<String, dynamic>
          ? FootballChatSticker.fromJson(stickerRaw)
          : null,
    );
  }
}

/// PRODUCT-05-B1: PUT/DELETE reaction response for Football Chat.
class FootballChatReactionsResult {
  const FootballChatReactionsResult({
    required this.messageId,
    this.reactions = const [],
    this.myReaction,
  });

  final String messageId;
  final List<ChatMessageReactionSummary> reactions;
  final String? myReaction;

  factory FootballChatReactionsResult.fromJson(Map<String, dynamic> json) {
    return FootballChatReactionsResult(
      messageId: json['messageId']?.toString() ?? '',
      reactions: parseChatReactions(json['reactions']),
      myReaction: ReactionType.tryParse(json['myReaction']?.toString())?.apiValue,
    );
  }
}

/// SONIC_06 read-only sports moment of a MATCH room (backend composes it from cached provider events;
/// never a chat message, never counted by the message rate limit).
class FootballChatEvent {
  const FootballChatEvent({required this.key, required this.kind, this.minute, this.extra,
    this.player, this.team, this.side, this.approxAt});
  final String key;
  /// GOAL, OWN_GOAL, PENALTY_GOAL, RED_CARD, SECOND_YELLOW, VAR_GOAL_CANCELLED,
  /// VAR_PENALTY_CONFIRMED, VAR_PENALTY_CANCELLED.
  final String kind;
  final int? minute;
  final int? extra;
  final String? player;
  final String? team;
  /// HOME / AWAY / null.
  final String? side;
  /// Ordering hint in the timeline (never shown as a time). Null when the kickoff is a placeholder.
  final DateTime? approxAt;

  factory FootballChatEvent.fromJson(Map<String, dynamic> json) => FootballChatEvent(
    key: json['key']?.toString() ?? '',
    kind: json['kind']?.toString() ?? '',
    minute: (json['minute'] as num?)?.toInt(),
    extra: (json['extra'] as num?)?.toInt(),
    player: json['player']?.toString(),
    team: json['team']?.toString(),
    side: json['side']?.toString(),
    approxAt: DateTime.tryParse(json['approxAt']?.toString() ?? '')?.toUtc(),
  );
}

class FootballChatPage {
  const FootballChatPage({required this.items, required this.hasMore, this.contextType = 'GENERAL',
    this.contextId, this.match, this.events = const [], this.eventsStale = false});
  final List<FootballChatMessage> items;
  final bool hasMore;
  final String contextType;
  final String? contextId;
  /// MATCH rooms: cached fixture header (teams, competition, round); null when not cached.
  final FootballMatch? match;
  final List<FootballChatEvent> events;
  final bool eventsStale;
}

/// SONIC_03 Chat Futbolero — polls Garra backend (no second realtime stack).
/// SONIC_06: rooms (GENERAL / MATCH) and read-only sports moments.
class FootballChatService {
  FootballChatService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// GENERAL room (SONIC_03 contract).
  Future<FootballChatPage> messages({DateTime? before, int size = 30}) =>
      page(const FootballChatContext.general(), before: before, size: size);

  Future<FootballChatPage> page(
    FootballChatContext context, {
    DateTime? before,
    String? beforeId,
    int size = 30,
  }) async {
    if (beforeId != null && before == null) {
      throw ArgumentError('before is required when beforeId is set');
    }
    final response = await _dio.get('/football/chat/messages', queryParameters: {
      if (before != null) 'before': before.toUtc().toIso8601String(),
      if (beforeId != null && beforeId.isNotEmpty) 'beforeId': beforeId,
      'size': size,
      'context': ?context.wire,
    });
    final envelope = response.data;
    if (envelope is! Map || envelope['data'] is! Map) {
      throw const FormatException('Chat Futbolero: unexpected envelope');
    }
    final data = Map<String, dynamic>.from(envelope['data'] as Map);
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FootballChatMessage.fromJson)
        .toList();
    final match = data['match'];
    return FootballChatPage(
      items: items,
      hasMore: data['hasMore'] == true,
      contextType: data['contextType']?.toString() ?? 'GENERAL',
      contextId: data['contextId']?.toString(),
      match: match is Map<String, dynamic> ? FootballMatch.fromJson(match) : null,
      events: ((data['events'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FootballChatEvent.fromJson)
          .where((e) => e.key.isNotEmpty && e.kind.isNotEmpty)
          .toList(),
      eventsStale: data['eventsStale'] == true,
    );
  }

  Future<FootballChatMessage> send(
    String body, {
    FootballChatContext context = const FootballChatContext.general(),
    String? clientMessageId,
    String? replyToMessageId,
  }) async =>
      sendPayload(
        context: context,
        clientMessageId: clientMessageId,
        replyToMessageId: replyToMessageId,
        body: body,
      );

  Future<FootballChatMessage> sendSticker(
    String stickerId, {
    FootballChatContext context = const FootballChatContext.general(),
    String? clientMessageId,
    String? replyToMessageId,
  }) async =>
      sendPayload(
        context: context,
        clientMessageId: clientMessageId,
        replyToMessageId: replyToMessageId,
        messageType: 'STICKER',
        stickerId: stickerId,
      );

  Future<FootballChatMessage> sendPayload({
    FootballChatContext context = const FootballChatContext.general(),
    String? clientMessageId,
    String? replyToMessageId,
    String? body,
    String messageType = 'TEXT',
    String? stickerId,
  }) async {
    final response = await _dio.post('/football/chat/messages', data: {
      if (body != null && body.isNotEmpty) 'body': body,
      if (messageType != 'TEXT') 'messageType': messageType,
      if (stickerId != null && stickerId.isNotEmpty) 'stickerId': stickerId,
      'context': ?context.wire,
      if (clientMessageId != null && clientMessageId.isNotEmpty)
        'clientMessageId': clientMessageId,
      if (replyToMessageId != null && replyToMessageId.isNotEmpty)
        'replyToMessageId': replyToMessageId,
    });
    final data = response.data is Map ? (response.data as Map)['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Chat Futbolero: unexpected send envelope');
    }
    return FootballChatMessage.fromJson(data);
  }

  /// PRODUCT-03B-3B-3: report another fan's visible message (same body shape as wall reports).
  Future<ReportSubmitResult> reportMessage({
    required String messageId,
    required String category,
    String? reason,
  }) async {
    try {
      await _dio.post(
        '/football/chat/messages/$messageId/report',
        data: ReportWallPostRequest(category: category, reason: reason).toJson(),
      );
      return ReportSubmitResult.success();
    } on DioException catch (e) {
      return ReportSubmitResult.failure(garraMessageFromDio(e));
    } catch (_) {
      return ReportSubmitResult.failure(garraReportFallbackError);
    }
  }

  Future<FootballChatReactionsResult> reactToMessage(
    String messageId,
    ReactionType type,
  ) async {
    final response = await _dio.put(
      '/football/chat/messages/$messageId/reaction',
      data: {'reactionType': type.apiValue},
    );
    final data = response.data is Map ? (response.data as Map)['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Chat Futbolero: unexpected reaction envelope');
    }
    return FootballChatReactionsResult.fromJson(data);
  }

  Future<FootballChatReactionsResult> removeMessageReaction(String messageId) async {
    final response = await _dio.delete('/football/chat/messages/$messageId/reaction');
    final data = response.data is Map ? (response.data as Map)['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Chat Futbolero: unexpected reaction envelope');
    }
    return FootballChatReactionsResult.fromJson(data);
  }

  Future<FootballChatStickerCatalog> stickerCatalog() async {
    final response = await _dio.get('/football/chat/stickers');
    final data = response.data is Map ? (response.data as Map)['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Chat Futbolero: unexpected sticker catalog');
    }
    return FootballChatStickerCatalog.fromJson(data);
  }

  Future<List<FootballChatSticker>> stickerFavorites() async {
    final response = await _dio.get('/football/chat/stickers/favorites');
    return _parseStickerList(response.data);
  }

  Future<List<FootballChatSticker>> addStickerFavorite(String stickerId) async {
    final response = await _dio.put('/football/chat/stickers/favorites/$stickerId');
    return _parseStickerList(response.data);
  }

  Future<List<FootballChatSticker>> removeStickerFavorite(String stickerId) async {
    final response = await _dio.delete('/football/chat/stickers/favorites/$stickerId');
    return _parseStickerList(response.data);
  }

  List<FootballChatSticker> _parseStickerList(dynamic envelope) {
    final data = envelope is Map ? envelope['data'] : null;
    if (data is! Map<String, dynamic>) return const [];
    return FootballChatStickerCatalog.fromJson(data).items;
  }

  Future<ReportSubmitResult> deleteMessage(String messageId) async {
    try {
      await _dio.delete('/football/chat/messages/$messageId');
      return ReportSubmitResult.success();
    } on DioException catch (e) {
      return ReportSubmitResult.failure(garraMessageFromDio(e));
    } catch (_) {
      return ReportSubmitResult.failure('No pudimos eliminar el mensaje.');
    }
  }
}

String garraMessageFromDio(DioException e) {
  final body = e.response?.data;
  if (body is Map && body['message'] != null) {
    final msg = body['message'].toString().trim();
    if (msg.isNotEmpty) return msg;
  }
  return classifyDioError(e).message;
}
