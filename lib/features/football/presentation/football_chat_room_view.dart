import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../chat/presentation/chat_message_reactions.dart';
import '../../chat/presentation/chat_reply_tile.dart';
import '../../chat/presentation/chat_swipe_to_reply.dart';
import '../../community/data/reaction_type.dart';
import 'football_chat_message_reactions.dart';
import 'football_chat_quick_emojis.dart';
import 'football_chat_report_sheet.dart';
import 'football_chat_sticker_panel.dart';
import '../../../core/stickers/garra_sticker_assets.dart';
import '../../../core/stickers/garra_sticker_preloader.dart';
import '../../../core/widgets/garra_stickers.dart';

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
    this.focusMessageId,
  });

  final FootballChatSurface surface;
  final String? topic;
  final int? matchId;
  final FootballMatch? initialMatch;

  /// PRODUCT-08C: message to reveal after the room loads (reply push / inbox deep link `?messageId=`).
  final String? focusMessageId;

  static const pollEvery = Duration(seconds: 12);
  static const focusHighlightFor = Duration(milliseconds: 2500);
  static const focusNotLoadedCopy =
      'La respuesta está más arriba en el chat o ya no está disponible.';

  /// `messageId` query parameter of the current route, or null (also outside a GoRouter, e.g. tests).
  static String? routeMessageId(BuildContext context) {
    try {
      final id = GoRouterState.of(context).uri.queryParameters['messageId']?.trim();
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

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
    this.stickerId,
    this.stickerGlyph,
    this.stickerName,
  });
  final String localId;
  final String body;
  final String clientMessageId;
  final String? replyToMessageId;
  final FootballChatReplyPreview? replyTo;
  final String? stickerId;
  final String? stickerGlyph;
  final String? stickerName;
  bool failed = false;
  String? failureHint;

  bool get isSticker => stickerId != null && stickerId!.isNotEmpty;
}

class _FootballChatRoomViewState extends ConsumerState<FootballChatRoomView>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _composerFocus = FocusNode();
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
  final Map<String, List<ChatMessageReactionSummary>> _pendingReactions = {};
  final Map<String, int> _reactionTokens = {};
  var _reactionSeq = 0;
  var _reactionBusy = false;
  Timer? _poll;
  bool _foreground = true;
  bool _nearBottom = true;
  static const _historyTriggerPx = 96.0;
  // PRODUCT-08C: deep-link focus.
  String? _pendingFocus;
  String? _focusTargetId;
  String? _highlightId;
  final _focusKey = GlobalKey(debugLabel: 'chat_focus_target');
  Timer? _highlightTimer;
  static const _nearBottomPx = 80.0;

  @override
  void initState() {
    super.initState();
    _context = widget.surface == FootballChatSurface.community
        ? const FootballChatContext.general()
        : FootballChatContext.tryMatch(widget.matchId ?? widget.initialMatch?.id) ??
            const FootballChatContext.general();
    _match = _context.isMatch ? widget.initialMatch : null;
    _pendingFocus = widget.focusMessageId;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
      if (mounted) _warmStickers();
    });
  }

  /// PRODUCT-07B: sticker catalog + CDN config fetched once per room (shared future), early and
  /// non-blocking, instead of lazily when the panel opens.
  Future<FootballChatStickerCatalog>? _stickerCatalogFuture;

  Future<FootballChatStickerCatalog> _loadStickerCatalog() =>
      _stickerCatalogFuture ??= () async {
        try {
          await GarraStickerAssets.ensureRemoteConfig();
          return await ref.read(footballChatServiceProvider).stickerCatalog();
        } catch (_) {
          _stickerCatalogFuture = null; // allow a later retry (e.g. panel open)
          rethrow;
        }
      }();

  void _warmStickers() {
    final hadBase = GarraStickerAssets.baseUrl != null;
    unawaited(_loadStickerCatalog().then((catalog) {
      if (!mounted) return;
      // CDN base may have just arrived: rebuild so already-rendered stickers switch from glyph to image.
      if (!hadBase && GarraStickerAssets.baseUrl != null) setState(() {});
      // Bounded, deduped 128px thumbnail warm-up (sequential, max 16); never the 512 pack.
      unawaited(GarraStickerPreloader.warmThumbs(
        context,
        catalog.items.map((s) => s.assetKey),
      ));
    }, onError: (Object _) {}));
  }

  @override
  void didUpdateWidget(covariant FootballChatRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focusMessageId;
    if (focus != null && focus != oldWidget.focusMessageId) {
      _pendingFocus = focus;
      if (_loaded) {
        // The message may be newer than the last poll: refresh first, then focus.
        _load(silent: true).whenComplete(_scheduleFocus);
      }
    }
  }

  void _scheduleFocus() {
    if (_pendingFocus == null || !mounted || !_loaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocus());
  }

  /// Scrolls to the focused message when it is in the loaded window and highlights it briefly; otherwise
  /// stays at the latest messages and says so (never pretends to have found it).
  Future<void> _applyFocus() async {
    final id = _pendingFocus;
    if (id == null || !mounted || !_loaded) return;
    _pendingFocus = null;
    final entries = _timeline;
    final index = entries.indexWhere((e) => e is FootballChatMessage && e.id == id);
    if (index < 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          key: ValueKey('chat_focus_not_loaded'),
          content: Text(FootballChatRoomView.focusNotLoadedCopy),
        ),
      );
      return;
    }
    _highlightTimer?.cancel();
    setState(() {
      _focusTargetId = id;
      _highlightId = id;
    });
    for (var attempt = 0; attempt < 4 && mounted; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final target = _focusKey.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.35,
          duration: const Duration(milliseconds: 250),
        );
        break;
      }
      if (!_scroll.hasClients) break;
      // Lazily built list: jump near the estimated position so the item gets built, then retry.
      final maxExtent = _scroll.position.maxScrollExtent;
      final ratio = entries.length <= 1 ? 1.0 : index / (entries.length - 1);
      _scroll.jumpTo((maxExtent * ratio).clamp(0.0, maxExtent));
    }
    if (!mounted) return;
    _highlightTimer = Timer(FootballChatRoomView.focusHighlightFor, () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  Widget _focusWrap(String id, Widget child) {
    if (id != _focusTargetId) return child;
    final highlighted = id == _highlightId;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      key: _focusKey,
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primary.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: KeyedSubtree(
        key: ValueKey(highlighted ? 'chat_focus_highlight_$id' : 'chat_focus_target_$id'),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _controller.dispose();
    _composerFocus.dispose();
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
      _pendingReactions.clear();
      _reactionTokens.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  List<ChatMessageReactionSummary> _reactionsOf(FootballChatMessage message) =>
      _pendingReactions[message.id] ?? message.reactions;

  void _replaceReactionsInState(String id, List<ChatMessageReactionSummary> reactions) {
    _items = [
      for (final m in _items) m.id == id ? m.copyWith(reactions: reactions) : m,
    ];
    final unseen = _unseen[id];
    if (unseen != null) {
      _unseen[id] = unseen.copyWith(reactions: reactions);
    }
  }

  Future<void> _openReactions(
    BuildContext bubbleContext,
    FootballChatMessage message,
    bool mine,
  ) async {
    if (!_loaded || message.id.isEmpty || _reactionBusy) return;
    final box = bubbleContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    HapticFeedback.selectionClick();
    final selected = await showChatReactionPicker(
      context,
      anchor: anchor,
      alignEnd: mine && _cremaChat,
      current: myChatReaction(_reactionsOf(message)),
      actions: [
        ChatMessageAction(
          key: const ValueKey('chat_action_reply'),
          label: 'Responder',
          icon: Icons.reply_outlined,
          onSelected: () => _startReply(message),
        ),
        if (!mine)
          ChatMessageAction(
            key: const ValueKey('chat_action_report'),
            label: 'Reportar mensaje',
            icon: Icons.flag_outlined,
            onSelected: () => _reportMessage(message),
          ),
        if (mine)
          ChatMessageAction(
            key: const ValueKey('chat_action_delete'),
            label: 'Eliminar mensaje',
            icon: Icons.delete_outline,
            destructive: true,
            onSelected: () => _deleteOwnMessage(message),
          ),
      ],
    );
    if (selected == null || !mounted) return;
    await _react(message, selected, anchor, mine);
  }

  Future<void> _react(
    FootballChatMessage message,
    ReactionType type,
    Rect anchor,
    bool mine,
  ) async {
    if (!mounted || message.id.isEmpty) return;
    final id = message.id;
    final current = _reactionsOf(message);
    final removing = myChatReaction(current) == type.apiValue;
    final token = ++_reactionSeq;
    setState(() {
      _reactionTokens[id] = token;
      _pendingReactions[id] = withMyChatReaction(current, removing ? null : type.apiValue);
      _reactionBusy = true;
    });
    if (!removing &&
        type == ReactionType.garra &&
        anchor.width > 0 &&
        anchor.height > 0) {
      showChatGarraPulse(
        context,
        Offset(
          mine && _cremaChat ? anchor.right - 24 : anchor.left + 24,
          anchor.bottom,
        ),
      );
    }
    final chat = ref.read(footballChatServiceProvider);
    try {
      final result = removing
          ? await chat.removeMessageReaction(id)
          : await chat.reactToMessage(id, type);
      if (!mounted || _reactionTokens[id] != token) return;
      setState(() {
        _replaceReactionsInState(id, result.reactions);
        _pendingReactions.remove(id);
        _reactionTokens.remove(id);
        _reactionBusy = false;
      });
    } catch (_) {
      if (!mounted || _reactionTokens[id] != token) return;
      setState(() {
        _pendingReactions.remove(id);
        _reactionTokens.remove(id);
        _reactionBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos actualizar la reacci\u00f3n')),
      );
    }
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
        content: _replyPreviewText(message),
      );

  /// PRODUCT-07A: resolves a sticker from local data only (server object first, then the local
  /// 34-entry catalog by id) so pending/quoted stickers render the image; no network contract change.
  FootballChatSticker? _resolveSticker(
    String? id, {
    FootballChatSticker? server,
    String? name,
    String? glyph,
  }) {
    if (server != null && (server.assetKey ?? '').isNotEmpty) return server;
    final local = (id == null || id.isEmpty) ? null : GarraSticker.byId(id);
    if (local == null) {
      if (server != null) return server;
      if (id == null || id.isEmpty) return null;
      return FootballChatSticker(id: id, name: name ?? '', category: '', glyph: glyph ?? '');
    }
    return FootballChatSticker(
      id: local.stableId,
      name: (server?.name.isNotEmpty ?? false)
          ? server!.name
          : ((name?.isNotEmpty ?? false) ? name! : local.label),
      category: server?.category ?? local.category,
      glyph: (server?.glyph.isNotEmpty ?? false)
          ? server!.glyph
          : ((glyph?.isNotEmpty ?? false) ? glyph! : local.glyph),
      assetKey: server?.assetKey ?? local.assetKey,
    );
  }

  /// Readable reply preview: never a raw `:garra_x:` token (mirrors the server's `Sticker: <name>`).
  String _replyPreviewText(FootballChatMessage m) {
    if (m.isSticker) {
      final name = _resolveSticker(m.stickerId, server: m.sticker)?.name ?? '';
      return name.isEmpty ? 'Sticker' : 'Sticker: $name';
    }
    final token = GarraSticker.fromContent(m.body);
    if (token != null) return 'Sticker: ${token.label}';
    return m.body;
  }

  /// Sticker shown by a quote: the loaded original message, an exact token, or the server's
  /// `Sticker: <name>` preview mapped to loaded messages / local catalog. Null = plain text quote.
  FootballChatSticker? _quotedSticker(FootballChatReplyPreview reply) {
    if (reply.unavailable) return null;
    final loaded = [..._items, ..._unseen.values];
    if (reply.id.isNotEmpty) {
      for (final m in loaded) {
        if (m.id == reply.id) {
          return m.isSticker ? _resolveSticker(m.stickerId, server: m.sticker) : null;
        }
      }
    }
    final p = reply.preview.trim();
    final token = GarraSticker.fromContent(p);
    if (token != null) return _resolveSticker(token.stableId);
    const prefix = 'Sticker: ';
    if (p.startsWith(prefix)) {
      final name = p.substring(prefix.length).trim();
      for (final m in loaded) {
        if (m.isSticker && m.sticker?.name == name) {
          return _resolveSticker(m.stickerId, server: m.sticker);
        }
      }
      for (final s in GarraSticker.all) {
        if (s.label.toLowerCase() == name.toLowerCase()) return _resolveSticker(s.stableId);
      }
    }
    return null;
  }

  Widget _stickerThumb(FootballChatSticker s, {Key? key}) => SizedBox(
        key: key,
        width: 40,
        height: 40,
        child: GarraStickerImage(
          id: s.id,
          assetKey: s.assetKey,
          glyph: s.glyph,
          size: 40,
          thumb: true,
        ),
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
      if (first) _scheduleFocus();
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

  Future<void> _sendSticker(FootballChatSticker sticker, {_Outgoing? retry}) async {
    if (_sending || !_loaded || sticker.id.isEmpty) return;
    final room = _context;
    final generation = _generation;
    final replyTarget = _replyTarget;
    final replyPreview = replyTarget == null
        ? null
        : FootballChatReplyPreview(
            id: replyTarget.id,
            authorId: replyTarget.authorId,
            authorName: replyTarget.authorName,
            preview: _replyPreviewText(replyTarget),
          );
    // A retry reuses the same _Outgoing (same clientMessageId) so the backend idempotency applies.
    final out = retry ?? _Outgoing(
      'local-${_seq++}',
      '',
      const Uuid().v4(),
      replyToMessageId: replyTarget?.id,
      replyTo: replyPreview,
      stickerId: sticker.id,
      stickerGlyph: sticker.glyph,
      stickerName: sticker.name,
    );
    setState(() {
      _sending = true;
      out.failed = false;
      out.failureHint = null;
      if (retry == null) {
        _outgoing.add(out);
        _replyTarget = null;
      }
    });
    _jumpToBottom();
    try {
      final message = await ref.read(footballChatServiceProvider).sendSticker(
            sticker.id,
            context: room,
            clientMessageId: out.clientMessageId,
            replyToMessageId: out.replyToMessageId,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _outgoing.remove(out);
        if (message.id.isNotEmpty && !_items.any((m) => m.id == message.id)) {
          _unseen[message.id] = message;
        }
      });
    } on DioException catch (error) {
      logFootballFailure('chat:send-sticker:${room.key}', error);
      if (!mounted || generation != _generation) return;
      setState(() {
        out.failed = true;
        out.failureHint = classifyDioError(error).message;
      });
    } catch (error) {
      logFootballFailure('chat:send-sticker:${room.key}', error);
      if (mounted && generation == _generation) {
        setState(() {
          out.failed = true;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _send([_Outgoing? retry]) async {
    if (_sending || !_loaded) return;
    if (retry?.isSticker == true) {
      await _sendSticker(FootballChatSticker(
        id: retry!.stickerId!,
        name: retry.stickerName ?? '',
        category: '',
        glyph: retry.stickerGlyph ?? '',
      ), retry: retry);
      return;
    }
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
            preview: _replyPreviewText(replyTarget),
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
            final message = entry as FootballChatMessage;
            return _focusWrap(message.id, _messageTile(message, text));
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

  /// PRODUCT-07B: Comunidad Crema colors follow the app theme (dark keeps the previous look).
  _CremaPalette get _pal => _CremaPalette.of(context);

  Widget _emptyCard(TextTheme text) {
    if (_cremaChat) {
      return Container(
        key: const ValueKey('chat_empty'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _pal.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Empieza la conversación crema',
              style: text.titleSmall?.copyWith(
                color: _pal.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sé el primero en dejar tu arenga para la U.',
              style: text.bodySmall?.copyWith(color: _pal.textSoft),
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
    final quotedSticker = _quotedSticker(reply);
    final rawToken = GarraSticker.fromContent(reply.preview);
    final content = reply.unavailable
        ? 'Mensaje no disponible'
        : quotedSticker != null
            ? (quotedSticker.name.isEmpty ? 'Sticker' : quotedSticker.name)
            : rawToken != null
                ? 'Sticker: ${rawToken.label}'
                : reply.preview;
    final border = mine ? _pal.ownBorder : _pal.otherBorder;
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
      child: Row(
        children: [
          if (quotedSticker != null) ...[
            _stickerThumb(quotedSticker, key: ValueKey('chat_quote_thumb_${reply.id}')),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _cremaChat ? _pal.quoteName(mine) : null,
            ),
          ),
          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: _cremaChat ? _pal.quoteText(mine) : null,
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }

  /// PRODUCT-07A: STICKER messages render as the transparent WebP only (no bubble, no label below).
  Widget _stickerMessage({
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
    FootballChatSticker? sticker,
  }) {
    final glyph = (sticker?.glyph.isNotEmpty ?? false) ? sticker!.glyph : body;
    final label = (sticker?.name.isNotEmpty ?? false) ? sticker!.name : 'Sticker';
    final meta = _cremaChat
        ? _pal.meta
        : Theme.of(context).colorScheme.onSurfaceVariant;
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 2),
                      child: InkWell(
                        onTap: onTapName,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(
                            color: _cremaChat ? _pal.gold : null,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (replyTo != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: _quotedReply(replyTo, text, mine: mine),
                    ),
                  Semantics(
                    label: 'Sticker $label',
                    image: true,
                    excludeSemantics: true,
                    child: SizedBox(
                      key: const ValueKey('chat_sticker_box'),
                      width: 144,
                      height: 144,
                      child: GarraStickerImage(
                        id: sticker?.id ?? 'unknown',
                        assetKey: sticker?.assetKey,
                        glyph: glyph,
                        size: 144,
                      ),
                    ),
                  ),
                  if (time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
                      child: Text(
                        time,
                        style: text.labelSmall?.copyWith(color: meta, fontSize: 10),
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
    bool isSticker = false,
    FootballChatSticker? sticker,
  }) {
    if (isSticker) {
      return _stickerMessage(
        key: key,
        name: name,
        time: time,
        body: body,
        text: text,
        footer: footer,
        opacity: opacity,
        onTapName: onTapName,
        mine: mine,
        replyTo: replyTo,
        sticker: sticker,
      );
    }
    final messageChild = Text(
            body,
            style: text.bodyMedium?.copyWith(
              color: _cremaChat ? _pal.bubbleText(mine) : null,
              height: 1.25,
            ),
          );
    if (_cremaChat) {
      final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
      final bubbleColor =
          mine ? _pal.ownBubble : _pal.otherBubble;
      final borderColor =
          mine ? _pal.ownBorder : _pal.otherBorder;
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
                                    color: _pal.gold,
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
                                  color: _pal.meta,
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
                          DefaultTextStyle(
                            style: text.bodyMedium!.copyWith(color: _pal.bubbleText(mine)),
                            child: messageChild,
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
                            color: _pal.meta,
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
                  messageChild,
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
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Responder'),
              subtitle: const Text('También puedes deslizar el mensaje a la derecha'),
              onTap: () => Navigator.pop(ctx, 'reply'),
            ),
            ListTile(
              key: const ValueKey('chat_action_react'),
              leading: const Icon(Icons.add_reaction_outlined),
              title: const Text('Reaccionar'),
              onTap: () => Navigator.pop(ctx, 'react'),
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
      case 'react':
        final selected = await showModalBottomSheet<ReactionType>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ChatReactionPicker(
                selected: myChatReaction(_reactionsOf(m)),
                onSelected: (type) => Navigator.pop(ctx, type),
              ),
            ),
          ),
        );
        if (selected != null) {
          await _react(m, selected, Rect.zero, mine);
        }
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
    // PRODUCT-07D: in light Comunidad Crema the menu lines up with the bubble, not with the name row.
    final lightCrema = _cremaChat && Theme.of(context).brightness == Brightness.light;
    final menu = IconButton(
      key: ValueKey('chat_msg_menu_${m.id}'),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.only(top: lightCrema && !m.isSticker ? 14 : 2),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: _cremaChat
            ? _pal.meta
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: 'Acciones del mensaje',
      onPressed: () => _openMessageActions(m, mine),
    );
    final reactions = _reactionsOf(m);
    Widget? reactionFooter;
    if (reactions.isNotEmpty) {
      reactionFooter = Padding(
        padding: EdgeInsets.only(top: 4, left: mine && !_cremaChat ? 0 : 4, right: 4),
        child: Align(
          alignment: mine && _cremaChat ? Alignment.centerRight : Alignment.centerLeft,
          child: FootballChatTappableReactionChips(
            messageId: m.id,
            reactions: reactions,
            onReactionTap: (type) {
              final box = context.findRenderObject();
              if (box is RenderBox && box.hasSize) {
                final anchor = box.localToGlobal(Offset.zero) & box.size;
                _react(m, type, anchor, mine);
              }
            },
          ),
        ),
      );
    }
    final bubble = Builder(
      builder: (bubbleContext) => ChatSwipeToReply(
        onReply: () => _startReply(m),
        onLongPress: () => _openReactions(bubbleContext, m, mine),
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
          isSticker: m.isSticker,
          sticker: m.isSticker ? _resolveSticker(m.stickerId, server: m.sticker) : m.sticker,
          footer: reactionFooter,
          onTapName: widget.surface == FootballChatSurface.community && m.authorId.isNotEmpty
              ? () => _openAuthorProfile(m)
              : null,
        ),
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
        isSticker: out.isSticker,
        // PRODUCT-07A: local catalog assetKey -> the pending sticker shows its image immediately.
        sticker: out.isSticker
            ? _resolveSticker(out.stickerId, name: out.stickerName, glyph: out.stickerGlyph)
            : null,
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

  Future<void> _openStickerPanel() async {
    final chat = ref.read(footballChatServiceProvider);
    final picked = await showFootballChatStickerPanel(
      context,
      loadCatalog: _loadStickerCatalog,
      loadFavorites: chat.stickerFavorites,
      toggleFavorite: (id) async {
        final favs = await chat.stickerFavorites();
        final exists = favs.any((s) => s.id == id);
        return exists ? chat.removeStickerFavorite(id) : chat.addStickerFavorite(id);
      },
    );
    if (picked == null || !mounted) return;
    await _sendSticker(picked);
  }

  Widget _composer(TextTheme text) {
    final blocked = !_loaded;
    final crema = _cremaChat;
    // PRODUCT-07C: compact composer (40 dp controls, dense single-line field that grows to 5 lines).
    const btn = BoxConstraints.tightFor(width: 40, height: 40);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
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
                    color: crema ? _pal.textSoft : null,
                  ),
                ),
              ),
            if (_replyTarget != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (_replyTarget!.isSticker &&
                        _resolveSticker(_replyTarget!.stickerId, server: _replyTarget!.sticker) != null) ...[
                      _stickerThumb(
                        _resolveSticker(_replyTarget!.stickerId, server: _replyTarget!.sticker)!,
                        key: const ValueKey('chat_reply_composer_thumb'),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: ChatReplyTile(
                        key: const ValueKey('chat_reply_composer'),
                        reply: _composerReplyPreview(_replyTarget!),
                        onCancel: _cancelReply,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const ValueKey('football_chat_emoji_btn'),
                  tooltip: 'Emojis',
                  constraints: btn,
                  padding: EdgeInsets.zero,
                  onPressed: blocked || _sending
                      ? null
                      : () => showFootballChatEmojiPicker(
                            context,
                            _controller,
                            maxLength: 280,
                          ).then((_) {
                            if (mounted) _composerFocus.requestFocus();
                          }),
                  icon: Icon(
                    Icons.emoji_emotions_outlined,
                    color: crema ? _pal.gold : null,
                  ),
                ),
                IconButton(
                  key: const ValueKey('football_chat_sticker_btn'),
                  tooltip: 'Stickers',
                  constraints: btn,
                  padding: EdgeInsets.zero,
                  onPressed: blocked || _sending ? null : _openStickerPanel,
                  icon: Icon(
                    Icons.sticky_note_2_outlined,
                    color: crema ? _pal.gold : null,
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat_input'),
                    controller: _controller,
                    focusNode: _composerFocus,
                    enabled: !blocked,
                    maxLength: 280,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    style: crema ? TextStyle(color: _pal.text) : null,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu arenga...',
                      hintMaxLines: 1,
                      isDense: true,
                      hintStyle: crema
                          ? TextStyle(color: _pal.hint)
                          : null,
                      counterText: '',
                      filled: crema,
                      fillColor: crema ? _pal.inputFill : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: crema ? _pal.inputBorder : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: crema ? _pal.inputBorder : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: crema ? _pal.gold : Theme.of(context).colorScheme.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  key: const ValueKey('chat_send'),
                  constraints: btn,
                  padding: EdgeInsets.zero,
                  style: crema
                      ? IconButton.styleFrom(
                          backgroundColor: _pal.sendBg,
                          foregroundColor: _pal.sendFg,
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

/// PRODUCT-07B: Comunidad Crema palette per theme brightness. `dark` = the original colors;
/// `light` keeps the guinda/gold identity with readable contrast on light backgrounds.
class _CremaPalette {
  const _CremaPalette({
    required this.card,
    required this.cardBorder,
    required this.text,
    required this.textSoft,
    required this.gold,
    required this.meta,
    required this.ownBubble,
    required this.otherBubble,
    required this.ownBorder,
    required this.otherBorder,
    required this.ownText,
    required this.otherText,
    required this.ownQuoteName,
    required this.ownQuoteText,
    required this.hint,
    required this.inputFill,
    required this.inputBorder,
    required this.sendBg,
    required this.sendFg,
  });

  final Color card;
  final Color cardBorder;
  final Color text;
  final Color textSoft;
  final Color gold;
  final Color meta;
  final Color ownBubble;
  final Color otherBubble;
  final Color ownBorder;
  final Color otherBorder;
  final Color ownText;
  final Color otherText;
  final Color ownQuoteName;
  final Color ownQuoteText;
  final Color hint;
  final Color inputFill;
  final Color inputBorder;
  final Color sendBg;
  final Color sendFg;

  Color bubbleText(bool mine) => mine ? ownText : otherText;
  Color quoteName(bool mine) => mine ? ownQuoteName : gold;
  Color quoteText(bool mine) => mine ? ownQuoteText : textSoft;

  static const dark = _CremaPalette(
    card: Color(0xCC1A1214),
    cardBorder: Color(0x55C7A45B),
    text: Color(0xFFF3E9D2),
    textSoft: Color(0xFFD3C5B0),
    gold: Color(0xFFC7A45B),
    meta: Color(0xFF9A8B7A),
    ownBubble: Color(0xFF6E2A35),
    otherBubble: Color(0xE6221A1C),
    ownBorder: Color(0x88C7A45B),
    otherBorder: Color(0x44C7A45B),
    ownText: Color(0xFFF3E9D2),
    otherText: Color(0xFFF3E9D2),
    ownQuoteName: Color(0xFFC7A45B),
    ownQuoteText: Color(0xFFD3C5B0),
    hint: Color(0xFF8A7A6A),
    inputFill: Color(0xCC221A1C),
    inputBorder: Color(0x55C7A45B),
    sendBg: Color(0xFFC7A45B),
    sendFg: Color(0xFF211416),
  );

  static const light = _CremaPalette(
    card: Color(0xFFFBF6EC),
    cardBorder: Color(0x668A6A1F),
    text: Color(0xFF2A1A1C),
    textSoft: Color(0xFF5B4B42),
    // PRODUCT-07D: warmer cream bubbles (no pure white), stronger name/meta contrast on cream.
    gold: Color(0xFF6A4C0E),
    meta: Color(0xFF5E5047),
    ownBubble: Color(0xFF7C0211),
    otherBubble: Color(0xFFFCF6EA),
    ownBorder: Color(0x667C0211),
    otherBorder: Color(0x598A6A1F),
    ownText: Color(0xFFFFF8EC),
    otherText: Color(0xFF2A1A1C),
    ownQuoteName: Color(0xFFF3D9A0),
    ownQuoteText: Color(0xFFF1E4D2),
    hint: Color(0xFF7D6F64),
    inputFill: Color(0xFFFFFFFF),
    inputBorder: Color(0x668A6A1F),
    sendBg: Color(0xFF7C0211),
    sendFg: Color(0xFFFFFFFF),
  );

  static _CremaPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
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
