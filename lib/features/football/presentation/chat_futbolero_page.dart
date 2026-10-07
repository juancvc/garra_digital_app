import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_status.dart';
import '../data/football_chat_service.dart';
import '../data/football_diagnostics.dart';
import '../data/garra_football_models.dart';

final footballChatServiceProvider =
    Provider<FootballChatService>((ref) => FootballChatService());

/// SONIC_03: Chat Futbolero from Centro Garra (not match Tribuna).
/// SONIC_06: one chat domain with rooms. GENERAL from Centro Garra; MATCH from "Hablar del partido"
/// ([matchId]), with the match header from data and read-only sports moments interleaved. Exactly one
/// poller (~12 s) for the visible room: switching room cancels it, leaving the page or sending the app to
/// background stops it. No WebSocket / SSE (future evolution).
class ChatFutboleroPage extends ConsumerStatefulWidget {
  const ChatFutboleroPage({super.key, this.topic, this.matchId, this.match});

  /// SONIC_04 legacy "Home vs Away" text (header fallback while the match room loads).
  final String? topic;

  /// SONIC_06: provider fixture id of the MATCH room; null = GENERAL.
  final int? matchId;

  /// Match already known by the caller (detail), so the header is right before the first answer.
  final FootballMatch? match;

  static const pollEvery = Duration(seconds: 12);

  @override
  ConsumerState<ChatFutboleroPage> createState() => _ChatFutboleroPageState();
}

class _Outgoing {
  _Outgoing(this.localId, this.body);
  final String localId;
  final String body;
  bool failed = false;
}

class _ChatFutboleroPageState extends ConsumerState<ChatFutboleroPage> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late FootballChatContext _context;
  FootballMatch? _match;
  List<FootballChatMessage> _items = const [];
  /// Confirmed sends not yet present in a server page (a poll that started before the send).
  final Map<String, FootballChatMessage> _unseen = {};
  final List<_Outgoing> _outgoing = [];
  List<FootballChatEvent> _events = const [];
  bool _eventsStale = false;
  bool _loading = true;
  bool _loaded = false;
  FootballFailureLayer? _failure;
  bool _sending = false;
  bool _inFlight = false;
  int _generation = 0;
  int _seq = 0;
  Timer? _poll;
  bool _foreground = true;
  /// SONIC_06A: avoid yanking the reader down on silent polls.
  bool _nearBottom = true;

  @override
  void initState() {
    super.initState();
    _context = FootballChatContext.tryMatch(widget.matchId ?? widget.match?.id) ?? const FootballChatContext.general();
    _match = _context.isMatch ? widget.match : null;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_foreground) return;
      _foreground = true;
      _load(silent: _loaded);
    } else {
      _foreground = false;
      _stopPolling();
    }
  }

  void _ensurePolling() {
    if (_poll != null || !_foreground || !mounted || !_loaded) return;
    _poll = Timer.periodic(ChatFutboleroPage.pollEvery, (_) {
      if (mounted && !_sending) _load(silent: true);
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _load({bool silent = false}) async {
    if (_inFlight) return;
    final generation = _generation;
    final room = _context;
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      if (!silent) setState(() { _loading = false; if (!_loaded) _failure = FootballFailureLayer.appNetwork; });
      return;
    }
    _inFlight = true;
    if (!silent) setState(() { _loading = true; _failure = null; });
    try {
      final page = await ref.read(footballChatServiceProvider).page(room);
      if (!mounted || generation != _generation) return;
      final first = !_loaded;
      setState(() {
        final ids = {for (final m in page.items) m.id};
        _unseen.removeWhere((id, _) => ids.contains(id));
        _items = page.items;
        _events = page.events;
        _eventsStale = page.eventsStale;
        if (page.match != null) _match = page.match;
        _loaded = true;
        _failure = null;
      });
      if (first || _nearBottom) _jumpToBottom();
      _ensurePolling();
    } catch (error) {
      // Distinguish the failing layer in logs (path / status / type only, never payloads or tokens).
      logFootballFailure('chat:${room.key}', error);
      if (!mounted || generation != _generation) return;
      // A failed poll keeps what is on screen; only a room never loaded shows the error.
      if (!_loaded) setState(() => _failure = footballFailureLayer(error));
    } finally {
      if (generation == _generation) _inFlight = false;
      if (mounted && !silent && generation == _generation) setState(() => _loading = false);
    }
  }

  void _switchTo(FootballChatContext room) {
    if (room == _context) return;
    _stopPolling();
    setState(() {
      _generation++;
      _inFlight = false;
      _context = room;
      _match = null;
      _items = const [];
      _unseen.clear();
      _outgoing.clear();
      _events = const [];
      _eventsStale = false;
      _loaded = false;
      _failure = null;
      _loading = true;
    });
    _load();
  }

  Future<void> _send([_Outgoing? retry]) async {
    if (_sending || !_loaded) return;
    final body = retry?.body ?? _controller.text.trim();
    if (body.isEmpty) return;
    final room = _context;
    final generation = _generation;
    final out = retry ?? _Outgoing('local-${_seq++}', body);
    setState(() {
      _sending = true;
      out.failed = false;
      if (retry == null) {
        _outgoing.add(out);
        _controller.clear();
      }
    });
    _jumpToBottom();
    try {
      final message = await ref.read(footballChatServiceProvider).send(body, context: room);
      if (!mounted) return;
      setState(() {
        _outgoing.remove(out);
        if (generation == _generation && message.id.isNotEmpty && !_items.any((m) => m.id == message.id)) {
          _unseen[message.id] = message;
        }
      });
    } catch (error) {
      logFootballFailure('chat:send:${room.key}', error);
      if (mounted) setState(() => out.failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // During the room cross-fade the old and the new list may both be attached: move every attached one.
      for (final position in _scroll.positions.toList()) {
        position.jumpTo(position.maxScrollExtent);
      }
      _nearBottom = true;
    });
  }

  bool _onChatScroll(ScrollNotification note) {
    if (note.metrics.axis != Axis.vertical) return false;
    if (note is ScrollUpdateNotification || note is UserScrollNotification) {
      final remaining = note.metrics.maxScrollExtent - note.metrics.pixels;
      _nearBottom = remaining < 80;
    }
    return false;
  }

  String get _title {
    if (!_context.isMatch) return 'Chat Futbolero';
    final m = _match;
    if (m != null) return '${m.home} vs ${m.away}';
    final topic = widget.topic?.trim() ?? '';
    return topic.isEmpty ? 'Chat del partido' : topic;
  }

  /// Compact MATCH line: score/state · minute · competition · round.
  String? get _subtitle {
    final m = _match;
    if (!_context.isMatch || m == null) return null;
    final bits = <String>[];
    if (m.isLive || m.isFinished || m.homeScore != null) {
      bits.add('${m.homeScore ?? '–'}-${m.awayScore ?? '–'}');
    }
    if (m.isLive && !m.isUnconfirmed) {
      bits.add(m.liveMinuteLabel ?? m.statusLabel);
    } else if (m.isFinished) {
      bits.add('Final');
    } else if (m.status == 'POSTPONED') {
      bits.add('Postergado');
    }
    final meta = [if (m.competition.isNotEmpty) m.competition, ?m.roundLabel].join(' · ');
    if (meta.isNotEmpty) bits.add(meta);
    return bits.isEmpty ? null : bits.join(' · ');
  }

  /// Messages (server + confirmed sends) by time, sports moments by their minute hint; moments without
  /// a hint (placeholder kickoff) open the timeline in minute order. Pending / failed sends close it.
  List<Object> get _timeline {
    final messages = [..._items, ..._unseen.values.where((m) => !_items.any((s) => s.id == m.id))];
    final timed = <(DateTime, int, Object)>[];
    var order = 0;
    for (final m in messages) {
      timed.add((m.createdAt ?? DateTime.utc(9999), order++, m));
    }
    final untimed = <Object>[];
    for (final e in _events) {
      if (e.approxAt == null) {
        untimed.add(e);
      } else {
        timed.add((e.approxAt!, order++, e));
      }
    }
    timed.sort((a, b) {
      final t = a.$1.compareTo(b.$1);
      return t != 0 ? t : a.$2.compareTo(b.$2);
    });
    return [...untimed, for (final t in timed) t.$3, ..._outgoing];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = _subtitle;
    final legacyTopic = !_context.isMatch ? widget.topic?.trim() ?? '' : '';
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title, key: const ValueKey('chat_title'), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null)
            Text(subtitle, key: const ValueKey('chat_subtitle'), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: text.labelMedium),
        ]),
        actions: [
          if (_context.isMatch)
            TextButton.icon(
              key: const ValueKey('chat_back_general'),
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Chat general'),
              onPressed: () => _switchTo(const FootballChatContext.general()),
            ),
        ],
      ),
      body: Column(children: [
        if (legacyTopic.isNotEmpty)
          Container(
            key: const ValueKey('chat_topic_banner'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            child: Text('Hablando de: $legacyTopic', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
        if (_context.isMatch && _eventsStale)
          Padding(
            key: const ValueKey('chat_events_updating'),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(children: [
              Icon(Icons.sync, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Eventos actualizándose', style: text.labelSmall),
            ]),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(key: ValueKey('chat_body_${_context.key}_${_bodyState()}'), child: _body(text)),
          ),
        ),
        _composer(text),
      ]),
    );
  }

  String _bodyState() => !_loaded && _failure != null ? 'error' : !_loaded ? 'loading' : 'ready';

  Widget _body(TextTheme text) {
    if (!_loaded && _failure != null) {
      final detail = switch (_failure!) {
        FootballFailureLayer.appNetwork => 'Revisa tu conexión e inténtalo de nuevo.',
        FootballFailureLayer.auth => 'Tu sesión no es válida. Vuelve a iniciar sesión para usar el chat.',
        FootballFailureLayer.backend => 'El chat no respondió. Inténtalo en unos segundos.',
        _ => 'Inténtalo de nuevo en unos segundos.',
      };
      return ListView(key: const ValueKey('chat_error'), padding: const EdgeInsets.all(24), children: [
        Text('No pudimos cargar el chat', style: text.titleMedium),
        const SizedBox(height: 6),
        Text(detail, style: text.bodyMedium),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: TextButton(
            key: const ValueKey('chat_retry'), onPressed: _loading && _inFlight ? null : () => _load(),
            child: const Text('Reintentar'))),
      ]);
    }
    if (!_loaded) return const Center(child: CircularProgressIndicator(key: ValueKey('chat_loading')));
    final entries = _timeline;
    final hasMessages = entries.any((e) => e is FootballChatMessage || e is _Outgoing);
    final empty = hasMessages ? null : _emptyCard(text);
    return NotificationListener<ScrollNotification>(
      onNotification: _onChatScroll,
      child: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView.builder(
          key: const ValueKey('chat_list'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: entries.length + (empty == null ? 0 : 1),
          itemBuilder: (context, i) {
            if (i >= entries.length) return empty!;
            final entry = entries[i];
            if (entry is FootballChatEvent) return FootballChatEventCard(event: entry, match: _match);
            if (entry is _Outgoing) return _outgoingTile(entry, text);
            return _messageTile(entry as FootballChatMessage, text);
          },
        ),
      ),
    );
  }

  Widget _emptyCard(TextTheme text) => Card(
    key: const ValueKey('chat_empty'),
    margin: const EdgeInsets.only(top: 8),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_context.isMatch ? 'Abre la previa con la hinchada' : 'Empieza la conversación crema',
            style: text.titleMedium),
        const SizedBox(height: 6),
        Text(_context.isMatch
                ? 'Los mensajes de esta sala son solo de este partido.'
                : 'Sé el primero en dejar tu arenga.',
            style: text.bodyMedium),
      ])),
  );

  Widget _avatar(String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return CircleAvatar(radius: 16, child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)));
  }

  Widget _bubble({required Key key, required String name, required String? time, required String body,
      required TextTheme text, Widget? footer, double opacity = 1}) => Opacity(
    key: key,
    opacity: opacity,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _avatar(name),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800))),
            if (time != null) ...[
              const SizedBox(width: 6),
              Text(time, style: text.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ]),
          const SizedBox(height: 2),
          Text(body, style: text.bodyMedium),
          ?footer,
        ])),
      ]),
    ),
  );

  Widget _messageTile(FootballChatMessage m, TextTheme text) => _bubble(
    key: ValueKey('chat_msg_${m.id}'),
    name: m.authorName,
    time: m.createdAt == null ? null : footballClock(limaWallClock(m.createdAt!)),
    body: m.body,
    text: text,
  );

  Widget _outgoingTile(_Outgoing out, TextTheme text) => _bubble(
    key: ValueKey('chat_out_${out.localId}'),
    name: 'Tú',
    time: null,
    body: out.body,
    text: text,
    opacity: out.failed ? 1 : 0.6,
    footer: out.failed
        ? TextButton.icon(
            key: ValueKey('chat_retry_${out.localId}'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            icon: Icon(Icons.refresh, size: 16, color: Theme.of(context).colorScheme.error),
            label: Text('No se envió · Reintentar',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onPressed: _sending ? null : () => _send(out),
          )
        : Text('Enviando…', style: text.labelSmall),
  );

  Widget _composer(TextTheme text) {
    final blocked = !_loaded;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (blocked && _failure != null)
            Padding(
              key: const ValueKey('chat_composer_disabled'),
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Podrás escribir cuando el chat cargue.', style: text.bodySmall),
            ),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('chat_input'),
                controller: _controller,
                enabled: !blocked,
                maxLength: 280,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu arenga...',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('chat_send'),
              onPressed: blocked || _sending ? null : () => _send(),
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// SONIC_06 sports moment inside a MATCH room: read-only system card, home left / away right.
class FootballChatEventCard extends StatelessWidget {
  const FootballChatEventCard({super.key, required this.event, this.match});
  final FootballChatEvent event;
  final FootballMatch? match;

  static String label(FootballChatEvent e) {
    final n = footballNormalizeEvent(backendKind: e.kind);
    final emoji = switch (n.kind) {
      FootballEventKind.goal || FootballEventKind.penaltyGoal || FootballEventKind.ownGoal => '⚽',
      FootballEventKind.red || FootballEventKind.secondYellow => '🟥',
      FootballEventKind.videoReview => '📺',
      _ => '•',
    };
    return '$emoji ${n.label}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final who = [?event.player, ?event.team].join(' · ');
    final line = '${label(event)} ${footballMinuteLabel(event.minute, event.extra)}${who.isEmpty ? '' : ' · $who'}';
    // SONIC_06A: system strip — not a person bubble (no avatar, centered band, dashed outline).
    return Align(
      key: ValueKey('chat_event_${event.key}'),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.secondary.withValues(alpha: 0.45), width: 1),
        ),
        child: Column(children: [
          Text('EVENTO DEL PARTIDO', style: text.labelSmall?.copyWith(
              letterSpacing: 0.7, fontWeight: FontWeight.w800, color: scheme.secondary)),
          const SizedBox(height: 2),
          Text(line, key: ValueKey('chat_event_text_${event.kind}'), textAlign: TextAlign.center,
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
