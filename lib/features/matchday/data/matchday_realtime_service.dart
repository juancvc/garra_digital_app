import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'realtime_envelope.dart';

enum MatchdayRealtimeStatus { disconnected, connecting, connected, reconnecting }

typedef RealtimeEnvelopeHandler = void Function(RealtimeEnvelope envelope);

/// STOMP Matchday transport. One logical connection per active Matchday context.
class MatchdayRealtimeService {
  MatchdayRealtimeService({
    SecureStorageService? storage,
    String? websocketUrl,
    int maxDedupe = 300,
  })  : _storage = storage ?? SecureStorageService(),
        _websocketUrl = websocketUrl ?? ApiConfig.websocketUrl,
        _maxDedupe = maxDedupe;

  final SecureStorageService _storage;
  final String _websocketUrl;
  final int _maxDedupe;

  StompClient? _client;
  String? _subscribedMatchId;
  RealtimeEnvelopeHandler? _onEnvelope;
  final LinkedHashSet<String> _seenEventIds = LinkedHashSet<String>();
  final _statusController = StreamController<MatchdayRealtimeStatus>.broadcast();
  MatchdayRealtimeStatus _status = MatchdayRealtimeStatus.disconnected;
  int _attempt = 0;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;
  bool _connecting = false;
  int _connectGeneration = 0;

  Stream<MatchdayRealtimeStatus> get statusStream => _statusController.stream;
  MatchdayRealtimeStatus get status => _status;

  Future<void> connect({
    required String matchId,
    required RealtimeEnvelopeHandler onEnvelope,
  }) async {
    _intentionalDisconnect = false;
    _subscribedMatchId = matchId;
    _onEnvelope = onEnvelope;
    // Prevent rebuild/resume storms from stacking concurrent connects.
    if (_connecting ||
        (_status == MatchdayRealtimeStatus.connected &&
            _client != null &&
            _subscribedMatchId == matchId)) {
      return;
    }
    await _connectInternal();
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
    _connecting = false;
    _connectGeneration++;
    final client = _client;
    _client = null;
    _subscribedMatchId = null;
    _onEnvelope = null;
    try {
      client?.deactivate();
    } catch (_) {}
    _setStatus(MatchdayRealtimeStatus.disconnected);
  }

  Future<void> _connectInternal() async {
    if (_subscribedMatchId == null || _intentionalDisconnect) return;
    if (_connecting) return;
    _connecting = true;
    final generation = ++_connectGeneration;

    final token = await _storage.getToken();
    if (generation != _connectGeneration) {
      _connecting = false;
      return;
    }
    if (token == null || token.isEmpty) {
      _connecting = false;
      _setStatus(MatchdayRealtimeStatus.disconnected);
      return;
    }

    _setStatus(_attempt == 0
        ? MatchdayRealtimeStatus.connecting
        : MatchdayRealtimeStatus.reconnecting);

    try {
      _client?.deactivate();
    } catch (_) {}

    final client = StompClient(
      config: StompConfig(
        url: _websocketUrl,
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
          'access_token': token,
        },
        onConnect: (frame) {
          if (generation != _connectGeneration) return;
          _onConnect(frame);
        },
        onWebSocketError: (_) {
          if (generation != _connectGeneration) return;
          _scheduleReconnect();
        },
        onStompError: (_) {
          if (generation != _connectGeneration) return;
          _scheduleReconnect();
        },
        onDisconnect: (_) {
          if (generation != _connectGeneration) return;
          if (!_intentionalDisconnect) {
            _scheduleReconnect();
          }
        },
        reconnectDelay: const Duration(milliseconds: 0),
        heartbeatIncoming: const Duration(seconds: 20),
        heartbeatOutgoing: const Duration(seconds: 20),
      ),
    );
    _client = client;
    client.activate();
    _connecting = false;
  }

  void _onConnect(StompFrame frame) {
    _attempt = 0;
    _setStatus(MatchdayRealtimeStatus.connected);
    final matchId = _subscribedMatchId;
    final client = _client;
    if (matchId == null || client == null) return;
    client.subscribe(
      destination: '/topic/matchday/$matchId',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;
        try {
          final json = jsonDecode(body);
          if (json is! Map) return;
          final envelope =
              RealtimeEnvelope.fromJson(Map<String, dynamic>.from(json));
          if (!_accept(envelope.eventId)) return;
          _onEnvelope?.call(envelope);
        } catch (_) {}
      },
    );
  }

  bool _accept(String eventId) {
    if (eventId.isEmpty) return true;
    if (_seenEventIds.contains(eventId)) return false;
    _seenEventIds.add(eventId);
    while (_seenEventIds.length > _maxDedupe) {
      _seenEventIds.remove(_seenEventIds.first);
    }
    return true;
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _subscribedMatchId == null) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _setStatus(MatchdayRealtimeStatus.reconnecting);
    final delaySec = (() {
      final capped = _attempt.clamp(0, 5);
      return (1 << capped).clamp(1, 30);
    })();
    _attempt += 1;
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      _reconnectTimer = null;
      _connectInternal();
    });
  }

  void _setStatus(MatchdayRealtimeStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  /// Test helper: apply envelope through dedupe gate.
  bool debugAcceptEventId(String eventId) => _accept(eventId);

  int debugReconnectDelaySeconds(int attempt) {
    final capped = attempt.clamp(0, 5);
    return (1 << capped).clamp(1, 30);
  }

  void dispose() {
    disconnect();
    _statusController.close();
  }
}
