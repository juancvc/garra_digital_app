import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../auth/data/auth_user.dart';
import '../../../core/navigation/main_shell_branch_scope.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/network/garra_error.dart';
import '../data/football_chat_service.dart';
import '../data/football_chat_sync.dart';
import '../data/football_diagnostics.dart';
import '../data/garra_football_models.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_reply_tile.dart';
import '../../chat/presentation/chat_swipe_to_reply.dart';
import 'football_chat_report_sheet.dart';

final footballChatServiceProvider =
    Provider<FootballChatService>((ref) => FootballChatService());

enum FootballChatSurface { community, futbolero }

/// Shared Chat Futbolero room UI (GENERAL or MATCH). One poller per visible instance.
class FootballChatRoomView extends ConsumerStatefulWidget {
  const FootballChatRoomView({
    super.key,
    required this.surface,
    this.topic,
    this.matchId,
    this.initialMatch,
  });

  final FootballChatSurface surface;
  final String? topic;
  final int? matchId;
  final FootballMatch? initialMatch;

  static const pollEvery = Duration(seconds: 12);

  @override
  ConsumerState<FootballChatRoomView> createState() => _FootballChatRoomViewState();
}

class _Outgoing {
  _Outgoing(
    this.localId,
    this.body,
    this.clientMessageId, {
    this.replyToMessageId,
    this.replyTo,
  });
  final String localId;
  final String body;
  final String clientMessageId;
  final String? replyToMessageId;
  final FootballChatReplyPreview? replyTo;
  bool failed = false;
  String? failureHint;
}

class _FootballChatRoomViewState extends ConsumerState<FootballChatRoomView>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late FootballChatContext _context;
  FootballMatch? _match;
  List<FootballChatMessage> _items = const [];
  final Map<String, FootballChatMessage> _unseen = {};
  final List<_Outgoing> _outgoing = [];
  List<FootballChatEvent> _events = const [];
  bool _eventsStale = false;
  bool _loading = true;
  bool _loaded = false;
  FootballFailureLayer? _failure;
  bool _sending = false;
  bool _refreshInFlight = false;
  bool _historyInFlight = false;
  bool _hasMoreHistory = false;
  bool _historyFailed = false;
  bool _historyLoadQueued = false;
  int _pendingNewMessages = 0;
  int _generation = 0;
  FootballChatMessage? _replyTarget;
  int _seq = 0;
  Timer? _poll;
  bool _foreground = true;
  bool _nearBottom = true;
  static const _historyTriggerPx = 96.0;
  static const _nearBottomPx = 80.0;

  @override
  void initState() {
    super.initState();
    _context = widget.surface == FootballChatSurface.community
        ? const FootballChatContext.general()
        : FootballChatContext.tryMatch(widget.matchId ?? widget.initialMatch?.id) ??
            const FootballChatContext.general();
    _match = _context.isMatch ? widget.initialMatch : null;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shouldPoll()) {
      _stopPolling();
    } else if (_loaded) {
      _ensurePolling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_foreground) return;
      _foreground = true;
      if (_shouldPoll()) _load(silent: _loaded);
    } else {
      _foreground = false;
      _stopPolling();
    }
  }

  bool _shouldPoll() {
    if (!_foreground || !mounted) return false;
    final shellBranch = MainShellBranchScope.maybeOf(context)?.activeBranch;
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;

    switch (widget.surface) {
      case FootballChatSurface.community:
        if (shellBranch != null && shellBranch != 1) return false;
        return true;
      case FootballChatSurface.futbolero:
        if (shellBranch != null && shellBranch != 2) return false;
        return routeCurrent;
    }
  }

  void _ensurePolling() {
    if (_poll != null || !_shouldPoll() || !mounted || !_loaded) return;
    _poll = Timer.periodic(FootballChatRoomView.pollEvery, (_) {
      if (mounted && !_sending && _shouldPoll()) {
        _load(silent: true);
      } else if (!_shouldPoll()) {
        _stopPolling();
      }
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _resetForSessionChange() {
    _stopPolling();
    setState(() {
      _generation++;
      _refreshInFlight = false;
      _historyInFlight = false;
      _historyLoadQueued = false;
      _items = const [];
      _unseen.clear();
      _outgoing.clear();
      _events = const [];
      _eventsStale = false;
      _loaded = false;
      _loading = true;
      _failure = null;
      _hasMoreHistory = false;
      _historyFailed = false;
      _pendingNewMessages = 0;
      _nearBottom = true;
      _controller.clear();
      _replyTarget = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _startReply(FootballChatMessage message) {
    setState(() => _replyTarget = message);
  }

  void _cancelReply() {
    if (_replyTarget == null) return;
    setState(() => _replyTarget = null);
  }

  ChatReplyPreview _composerReplyPreview(FootballChatMessage message) =>
      ChatReplyPreview(
        id: message.id,
        senderId: message.authorId,
        senderName: message.authorName,
        content: message.body,
      );

  List<FootballChatMessage> _sortedUnique(Iterable<FootballChatMessage> source) =>
      footballChatSortedUnique(source);

  DateTime? _newestCreatedAt(Iterable<FootballChatMessage> items) {
    DateTime? newest;
    for (final m in items) {
      final t = m.createdAt;
      if (t == null) continue;
      if (newest == null || t.isAfter(newest)) newest = t;
    }
    return newest;
  }

  FootballChatMessage? get _oldestLoaded =>
      _items.isEmpty ? null : _items.first;

  /// Stable history cursor: same message supplies `before` and `beforeId`.
  DateTime? get _historyCursor => _oldestLoaded?.createdAt;

  String? get _historyBeforeId => _oldestLoaded?.id;

  void _applyInitialPage(FootballChatPage page) {
    final ids = {for (final m in page.items) m.id};
    _unseen.removeWhere((id, _) => ids.contains(id));
    _items = _sortedUnique(page.items);
    _hasMoreHistory = page.hasMore;
    _historyFailed = false;
    _events = page.events;
    _eventsStale = page.eventsStale;
    if (page.match != null) _match = page.match;
    _loaded = true;
    _failure = null;
    _pendingNewMessages = 0;
  }

  int _mergeLatestWindow(FootballChatPage page) {
    _items = reconcileFootballChatRecentWindow(
      local: _items,
      serverWindow: page.items,
    );
    final reconciledIds = {for (final m in page.items) m.id};
    _unseen.removeWhere((id, m) {
      if (reconciledIds.contains(id)) return false;
      if (page.items.isEmpty) return false;
      final anchor = page.items.first;
      final anchorAt = anchor.createdAt;
      if (anchorAt == null) return false;
      return footballChatIsSameOrNewer(m, anchorAt, anchor.id);
    });
    final known = {for (final m in _items) m.id, ..._unseen.keys};
    final previousNewest = _newestCreatedAt([..._items, ..._unseen.values]);
    var addedNew = 0;
    for (final m in page.items) {
      if (m.id.isEmpty || known.contains(m.id)) continue;
      final t = m.createdAt;
      if (previousNewest == null || t == null || t.isAfter(previousNewest)) {
        addedNew++;
      }
    }
    _items = _sortedUnique([..._items, ...page.items]);
    final ids = {for (final m in page.items) m.id};
    _unseen.removeWhere((id, _) => ids.contains(id));
    // Latest window only: sports moments refresh on the newest page.
    if (page.events.isNotEmpty || page.eventsStale) {
      _events = page.events;
      _eventsStale = page.eventsStale;
    }
    if (page.match != null) _match = page.match;
    return addedNew;
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshInFlight) return;
    final generation = _generation;
    final room = _context;
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      if (!silent) {
        setState(() {
          _loading = false;
          if (!_loaded) _failure = FootballFailureLayer.appNetwork;
        });
      }
      return;
    }
    _refreshInFlight = true;
    if (!silent) setState(() { _loading = true; _failure = null; });
    try {
      final page = await ref.read(footballChatServiceProvider).page(room);
      if (!mounted || generation != _generation) return;
      final first = !_loaded;
      setState(() {
        if (silent && _loaded) {
          final added = _mergeLatestWindow(page);
          if (added > 0 && !_nearBottom) {
            _pendingNewMessages += added;
          } else if (_nearBottom) {
            _pendingNewMessages = 0;
          }
        } else {
          _applyInitialPage(page);
        }
      });
      if (first || (_nearBottom && _pendingNewMessages == 0)) {
        _jumpToBottom(clearPending: first || _nearBottom);
      }
      _ensurePolling();
    } catch (error) {
      logFootballFailure('chat:${room.key}', error);
      if (!mounted || generation != _generation) return;
      if (!_loaded) setState(() => _failure = footballFailureLayer(error));
    } finally {
      if (generation == _generation) _refreshInFlight = false;
      if (mounted && !silent && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadOlderHistory() async {
    if (!_loaded || !_hasMoreHistory || _historyInFlight || _refreshInFlight) {
      return;
    }
    final cursor = _historyCursor;
    if (cursor == null) return;
    final generation = _generation;
    final room = _context;
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      setState(() => _historyFailed = true);
      return;
    }
    _historyInFlight = true;
    setState(() => _historyFailed = false);
    final position = _scroll.hasClients ? _scroll.position : null;
    final oldMax = position?.maxScrollExtent ?? 0;
    final oldPixels = position?.pixels ?? 0;
    try {
      final page = await ref.read(footballChatServiceProvider).page(
            room,
            before: cursor,
            beforeId: _historyBeforeId,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        final known = {for (final m in _items) m.id};
        final older = page.items.where((m) => !known.contains(m.id));
        _items = _sortedUnique([...older, ..._items]);
        _hasMoreHistory = page.hasMore;
        _historyFailed = false;
      });
      if (position != null && position.hasPixels) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          final delta = _scroll.position.maxScrollExtent - oldMax;
          _scroll.jumpTo(oldPixels + delta);
        });
      }
    } catch (error) {
      logFootballFailure('chat:history:${room.key}', error);
      if (mounted && generation == _generation) {
        setState(() {
          _historyFailed = true;
          _historyLoadQueued = false;
        });
      }
    } finally {
      if (generation == _generation) {
        _historyInFlight = false;
        _historyLoadQueued = false;
      }
      if (mounted && generation == _generation) setState(() {});
    }
  }

  void _switchTo(FootballChatContext room) {
    if (room == _context) return;
    _stopPolling();
    setState(() {
      _generation++;
      _refreshInFlight = false;
      _historyInFlight = false;
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
      _hasMoreHistory = false;
      _historyFailed = false;
      _pendingNewMessages = 0;
      _replyTarget = null;
    });
    _load();
  }

  Future<void> _send([_Outgoing? retry]) async {
    if (_sending || !_loaded) return;
    final body = retry?.body ?? _controller.text.trim();
    if (body.isEmpty) return;
    final room = _context;
    final generation = _generation;
    final replyTarget = retry == null ? _replyTarget : null;
    final replyPreview = replyTarget == null
        ? retry?.replyTo
        : FootballChatReplyPreview(
            id: replyTarget.id,
            authorId: replyTarget.authorId,
            authorName: replyTarget.authorName,
            preview: replyTarget.body,
          );
    final out = retry ??
        _Outgoing(
          'local-${_seq++}',
          body,
          const Uuid().v4(),
          replyToMessageId: replyTarget?.id,
          replyTo: replyPreview,
        );
    if (retry == null &&
        _outgoing.any((o) => !o.failed && o.body == body)) {
      return;
    }
    setState(() {
      _sending = true;
      out.failed = false;
      out.failureHint = null;
      if (retry == null) {
        _outgoing.add(out);
        _controller.clear();
        _replyTarget = null;
      }
    });
    _jumpToBottom();
    try {
      final message = await ref.read(footballChatServiceProvider).send(
            body,
            context: room,
            clientMessageId: out.clientMessageId,
            replyToMessageId: out.replyToMessageId,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _outgoing.remove(out);
        if (message.id.isNotEmpty &&
            !_items.any((m) => m.id == message.id)) {
          _unseen[message.id] = message;
        }
      });
    } on DioException catch (error) {
      logFootballFailure('chat:send:${room.key}', error);
      if (!mounted || generation != _generation) return;
      final info = classifyDioError(error);
      setState(() {
        out.failed = true;
        out.failureHint = info.message;
      });
    } catch (error) {
      logFootballFailure('chat:send:${room.key}', error);
      if (mounted && generation == _generation) {
        setState(() {
          out.failed = true;
          out.failureHint = null;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _reportMessage(FootballChatMessage message) async {
    await showFootballChatReportSheet(
      context,
      service: ref.read(footballChatServiceProvider),
      messageId: message.id,
    );
  }

  Future<void> _deleteOwnMessage(FootballChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar este mensaje?'),
        content: const Text(
          'Dejará de verse en el chat. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final generation = _generation;
    final result = await ref
        .read(footballChatServiceProvider)
        .deleteMessage(message.id);
    if (!mounted || generation != _generation) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    setState(() {
      _items = _items.where((m) => m.id != message.id).toList();
      _unseen.remove(message.id);
    });
  }

  void _jumpToBottom({bool clearPending = true}) {
    if (clearPending && _pendingNewMessages > 0) {
      setState(() => _pendingNewMessages = 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
      final nearBottom = remaining < _nearBottomPx;
      if (nearBottom && !_nearBottom && _pendingNewMessages > 0) {
        setState(() => _pendingNewMessages = 0);
      }
      _nearBottom = nearBottom;
      if (note.metrics.pixels <= _historyTriggerPx &&
          _hasMoreHistory &&
          !_historyInFlight &&
          !_historyLoadQueued) {
        _historyLoadQueued = true;
        _loadOlderHistory();
      }
    }
    return false;
  }

  String get _title {
    if (widget.surface == FootballChatSurface.community) {
      return 'Comunidad Crema';
    }
    if (!_context.isMatch) return 'Chat Futbolero';
    final m = _match;
    if (m != null) return '${m.home} vs ${m.away}';
    final topic = widget.topic?.trim() ?? '';
    return topic.isEmpty ? 'Chat del partido' : topic;
  }

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

  List<Object> get _timeline {
    final messages = [
      ..._items,
      ..._unseen.values.where((m) => !_items.any((s) => s.id == m.id)),
    ];
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

  void _openAuthorProfile(FootballChatMessage message) {
    final id = message.authorId.trim();
    if (id.isEmpty) return;
    context.push('/comunidad/u/$id');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentFanProvider);
    ref.listen<AsyncValue<AuthUser?>>(currentFanProvider, (previous, next) {
      final prevId = previous?.asData?.value?.id;
      final nextId = next.asData?.value?.id;
      if (prevId != null &&
          nextId != null &&
          prevId.isNotEmpty &&
          nextId.isNotEmpty &&
          prevId != nextId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resetForSessionChange();
        });
      }
    });
    final text = Theme.of(context).textTheme;
    final subtitle = _subtitle;
    final legacyTopic =
        widget.surface == FootballChatSurface.futbolero && !_context.isMatch
            ? widget.topic?.trim() ?? ''
            : '';
    final roomBody = Column(
      key: widget.surface == FootballChatSurface.community
          ? const ValueKey('community_chat_room')
          : null,
      children: [
        if (legacyTopic.isNotEmpty)
          Container(
            key: const ValueKey('chat_topic_banner'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            child: Text(
              'Hablando de: $legacyTopic',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        if (_context.isMatch && _eventsStale)
          Padding(
            key: const ValueKey('chat_events_updating'),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                Icon(Icons.sync,
                    size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Eventos actualizándose', style: text.labelSmall),
              ],
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey('chat_body_${_context.key}_${_bodyState()}'),
              child: _body(text),
            ),
          ),
        ),
        if (_pendingNewMessages > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(
              alignment: Alignment.center,
              child: FilledButton.tonal(
                key: const ValueKey('chat_new_messages_banner'),
                onPressed: () => _jumpToBottom(),
                child: Text(
                  _pendingNewMessages <= 1
                      ? 'Nuevos mensajes'
                      : 'Nuevos mensajes ($_pendingNewMessages)',
                ),
              ),
            ),
          ),
        _composer(text),
      ],
    );

    if (widget.surface == FootballChatSurface.community) {
      return roomBody;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title,
                key: const ValueKey('chat_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(subtitle,
                  key: const ValueKey('chat_subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium),
          ],
        ),
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
      body: roomBody,
    );
  }

  String _bodyState() =>
      !_loaded && _failure != null ? 'error' : !_loaded ? 'loading' : 'ready';

  Widget _body(TextTheme text) {
    if (!_loaded && _failure != null) {
      final detail = switch (_failure!) {
        FootballFailureLayer.appNetwork => 'Revisa tu conexión e inténtalo de nuevo.',
        FootballFailureLayer.auth =>
          'Tu sesión no es válida. Vuelve a iniciar sesión para usar el chat.',
        FootballFailureLayer.backend =>
          'El chat no respondió. Inténtalo en unos segundos.',
        _ => 'Inténtalo de nuevo en unos segundos.',
      };
      return ListView(
        key: const ValueKey('chat_error'),
        padding: const EdgeInsets.all(24),
        children: [
          Text('No pudimos cargar el chat', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(detail, style: text.bodyMedium),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('chat_retry'),
              onPressed: _loading && _refreshInFlight ? null : () => _load(),
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }
    if (!_loaded) {
      return const Center(
          child: CircularProgressIndicator(key: ValueKey('chat_loading')));
    }
    final entries = _timeline;
    final hasMessages =
        entries.any((e) => e is FootballChatMessage || e is _Outgoing);
    final empty = hasMessages ? null : _emptyCard(text);
    final headerCount = _listHeaderCount(hasMessages);
    return NotificationListener<ScrollNotification>(
      onNotification: _onChatScroll,
      child: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView.builder(
          key: const ValueKey('chat_list'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: headerCount + entries.length + (empty == null ? 0 : 1),
          itemBuilder: (context, i) {
            if (i < headerCount) return _listHeader(text, i, hasMessages);
            final entryIndex = i - headerCount;
            if (entryIndex >= entries.length) return empty!;
            final entry = entries[entryIndex];
            if (entry is FootballChatEvent) {
              return FootballChatEventCard(event: entry, match: _match);
            }
            if (entry is _Outgoing) return _outgoingTile(entry, text);
            return _messageTile(entry as FootballChatMessage, text);
          },
        ),
      ),
    );
  }

  int _listHeaderCount(bool hasMessages) {
    if (!hasMessages) return 0;
    var n = 0;
    if (_historyInFlight) n++;
    if (_historyFailed) n++;
    if (!_hasMoreHistory && _items.isNotEmpty) n++;
    return n;
  }

  Widget _listHeader(TextTheme text, int index, bool hasMessages) {
    var slot = 0;
    if (_historyInFlight) {
      if (index == slot++) {
        return const Padding(
          key: ValueKey('chat_history_loading'),
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
    }
    if (_historyFailed) {
      if (index == slot++) {
        return Align(
          key: const ValueKey('chat_history_retry'),
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: _historyInFlight ? null : _loadOlderHistory,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('No pudimos cargar mensajes anteriores'),
          ),
        );
      }
    }
    if (!_hasMoreHistory && _items.isNotEmpty && hasMessages) {
      if (index == slot) {
        return Padding(
          key: const ValueKey('chat_history_end'),
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Inicio de la conversación',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  bool get _cremaChat => widget.surface == FootballChatSurface.community;

  Widget _emptyCard(TextTheme text) {
    if (_cremaChat) {
      return Container(
        key: const ValueKey('chat_empty'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xCC1A1214),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x55C7A45B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Empieza la conversación crema',
              style: text.titleSmall?.copyWith(
                color: const Color(0xFFF3E9D2),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sé el primero en dejar tu arenga para la U.',
              style: text.bodySmall?.copyWith(color: const Color(0xFFD3C5B0)),
            ),
          ],
        ),
      );
    }
    return Card(
      key: const ValueKey('chat_empty'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _context.isMatch
                  ? 'Abre la previa con la hinchada'
                  : 'Empieza la conversación crema',
              style: text.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _context.isMatch
                  ? 'Los mensajes de esta sala son solo de este partido.'
                  : 'Sé el primero en dejar tu arenga.',
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name) {
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: 16,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _quotedReply(FootballChatReplyPreview? reply, TextTheme text, {bool mine = false}) {
    if (reply == null) return const SizedBox.shrink();
    final content = reply.unavailable ? 'Mensaje no disponible' : reply.preview;
    final border = mine ? const Color(0x66C7A45B) : const Color(0x44C7A45B);
    return Container(
      key: ValueKey('chat_quote_${reply.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: border, width: 3)),
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _cremaChat ? const Color(0xFFC7A45B) : null,
            ),
          ),
          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: _cremaChat ? const Color(0xFFD3C5B0) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble({
    required Key key,
    required String name,
    required String? time,
    required String body,
    required TextTheme text,
    Widget? footer,
    double opacity = 1,
    VoidCallback? onTapName,
    bool mine = false,
    FootballChatReplyPreview? replyTo,
  }) {
    if (_cremaChat) {
      final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
      final bubbleColor =
          mine ? const Color(0xFF6E2A35) : const Color(0xE6221A1C);
      final borderColor =
          mine ? const Color(0x88C7A45B) : const Color(0x44C7A45B);
      return Opacity(
        key: key,
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                _avatar(name),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: align,
                  children: [
                    if (!mine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2, left: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: InkWell(
                                onTap: onTapName,
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelSmall?.copyWith(
                                    color: const Color(0xFFC7A45B),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (time != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                time,
                                style: text.labelSmall?.copyWith(
                                  color: const Color(0xFF9A8B7A),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(mine ? 14 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 14),
                        ),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _quotedReply(replyTo, text, mine: mine),
                          Text(
                            body,
                            style: text.bodyMedium?.copyWith(
                              color: const Color(0xFFF3E9D2),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mine && time != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 2),
                        child: Text(
                          time,
                          style: text.labelSmall?.copyWith(
                            color: const Color(0xFF9A8B7A),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ?footer,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Opacity(
      key: key,
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: onTapName,
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(width: 6),
                        Text(time,
                            style: text.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  _quotedReply(replyTo, text, mine: mine),
                  Text(body, style: text.bodyMedium),
                  ?footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMessageActions(FootballChatMessage m, bool mine) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('chat_action_reply'),
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Responder'),
              onTap: () => Navigator.pop(ctx, 'reply'),
            ),
            if (!mine)
              ListTile(
                key: const ValueKey('chat_action_report'),
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Reportar mensaje'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            if (mine)
              ListTile(
                key: const ValueKey('chat_action_delete'),
                leading: const Icon(Icons.delete_outline),
                title: const Text('Eliminar mensaje'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'reply':
        _startReply(m);
      case 'report':
        await _reportMessage(m);
      case 'delete':
        await _deleteOwnMessage(m);
    }
  }

  Widget _messageTile(FootballChatMessage m, TextTheme text) {
    final me = currentFanIdOf(ref);
    final mine = isSameFanId(me, m.authorId);
    final menu = IconButton(
      key: ValueKey('chat_msg_menu_${m.id}'),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.only(top: 2),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: _cremaChat
            ? const Color(0xFF9A8B7A)
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: 'Acciones del mensaje',
      onPressed: () => _openMessageActions(m, mine),
    );
    final bubble = ChatSwipeToReply(
      onReply: () => _startReply(m),
      onLongPress: () => _openMessageActions(m, mine),
      child: _bubble(
        key: ValueKey('chat_msg_bubble_${m.id}'),
        name: m.authorName,
        time: m.createdAt == null
            ? null
            : footballClock(limaWallClock(m.createdAt!)),
        body: m.body,
        text: text,
        mine: mine,
        replyTo: m.replyTo,
        onTapName: widget.surface == FootballChatSurface.community && m.authorId.isNotEmpty
            ? () => _openAuthorProfile(m)
            : null,
      ),
    );
    return Row(
      key: ValueKey('chat_msg_${m.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: mine && _cremaChat ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (mine && _cremaChat) menu,
        Expanded(child: bubble),
        if (!mine || !_cremaChat) menu,
      ],
    );
  }

  Widget _outgoingTile(_Outgoing out, TextTheme text) => _bubble(
        key: ValueKey('chat_out_${out.localId}'),
        name: 'Tú',
        time: null,
        body: out.body,
        text: text,
        mine: true,
        replyTo: out.replyTo,
        opacity: out.failed ? 1 : 0.6,
        footer: out.failed
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (out.failureHint != null)
                    Text(out.failureHint!,
                        style: text.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.error)),
                  TextButton.icon(
                    key: ValueKey('chat_retry_${out.localId}'),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact),
                    icon: Icon(Icons.refresh,
                        size: 16, color: Theme.of(context).colorScheme.error),
                    label: Text('No se envió · Reintentar',
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.error)),
                    onPressed: _sending ? null : () => _send(out),
                  ),
                ],
              )
            : Text('Enviando…', style: text.labelSmall),
      );

  Widget _composer(TextTheme text) {
    final blocked = !_loaded;
    final crema = _cremaChat;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (blocked && _failure != null)
              Padding(
                key: const ValueKey('chat_composer_disabled'),
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Podrás escribir cuando el chat cargue.',
                  style: text.bodySmall?.copyWith(
                    color: crema ? const Color(0xFFD3C5B0) : null,
                  ),
                ),
              ),
            if (_replyTarget != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ChatReplyTile(
                  key: const ValueKey('chat_reply_composer'),
                  reply: _composerReplyPreview(_replyTarget!),
                  onCancel: _cancelReply,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat_input'),
                    controller: _controller,
                    enabled: !blocked,
                    maxLength: 280,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    style: crema ? const TextStyle(color: Color(0xFFF3E9D2)) : null,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu arenga...',
                      hintStyle: crema
                          ? const TextStyle(color: Color(0xFF8A7A6A))
                          : null,
                      counterText: '',
                      filled: crema,
                      fillColor: crema ? const Color(0xCC221A1C) : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: crema ? const Color(0x55C7A45B) : const Color(0xFF79747E),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: crema ? const Color(0x55C7A45B) : const Color(0xFF79747E),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: crema ? const Color(0xFFC7A45B) : Theme.of(context).colorScheme.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('chat_send'),
                  style: crema
                      ? IconButton.styleFrom(
                          backgroundColor: const Color(0xFFC7A45B),
                          foregroundColor: const Color(0xFF211416),
                        )
                      : null,
                  onPressed: blocked || _sending ? null : () => _send(),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// SONIC_06 sports moment inside a MATCH room: read-only system card.
class FootballChatEventCard extends StatelessWidget {
  const FootballChatEventCard({super.key, required this.event, this.match});
  final FootballChatEvent event;
  final FootballMatch? match;

  static String label(FootballChatEvent e) {
    final n = footballNormalizeEvent(backendKind: e.kind);
    final emoji = switch (n.kind) {
      FootballEventKind.goal ||
      FootballEventKind.penaltyGoal ||
      FootballEventKind.ownGoal =>
        '⚽',
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
    final line =
        '${label(event)} ${footballMinuteLabel(event.minute, event.extra)}${who.isEmpty ? '' : ' · $who'}';
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
        child: Column(
          children: [
            Text('EVENTO DEL PARTIDO',
                style: text.labelSmall?.copyWith(
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w800,
                    color: scheme.secondary)),
            const SizedBox(height: 2),
            Text(line,
                key: ValueKey('chat_event_text_${event.kind}'),
                textAlign: TextAlign.center,
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
