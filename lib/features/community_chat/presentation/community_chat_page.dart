import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_upload_service.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/utils/garra_message_time.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../../chat/data/chat_image_uploads.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_backdrop.dart';
import '../../chat/presentation/chat_conversation_page.dart'
    show chatCounterFromLength, chatFollowThreshold, chatMessageMaxLength;
import '../../chat/presentation/chat_media_grid.dart';
import '../../chat/presentation/chat_message_reactions.dart';
import '../../community/data/reaction_type.dart';
import '../data/community_chat_models.dart';
import '../data/community_chat_service.dart';
import 'community_chat_timeline.dart';

/// Distance to the top (px) that loads the previous page of history.
const double communityChatOlderThreshold = 200;

/// Max /changes pages applied in one polling cycle when `hasMore` is true.
const int communityChatMaxChangePages = 5;

const String communityChatReadOnlyCopy =
    'El chat est\u00e1 disponible en modo lectura.';
const String communityChatAccessLostCopy = 'Ya no tienes acceso a este chat.';

/// Optional identity passed by the clan detail through the route `extra` so
/// the header paints the logo/name before (and beyond) the chat info, which
/// carries no logo.
class CommunityChatSeed {
  const CommunityChatSeed({this.name, this.logoUrl});

  final String? name;
  final String? logoUrl;
}

/// COMMUNITY_GROUP_CHAT_14B: group chat of a community (`/clans/:slug/chat`).
/// Paginated by seq (latest page + `beforeSeq`), synced by version polling on
/// `/changes`, keyed by message id. Reuses the private chat building blocks
/// (backdrop, media grid, reactions, photo pipeline, time formatting).
class CommunityChatPage extends ConsumerStatefulWidget {
  const CommunityChatPage({
    super.key,
    required this.slug,
    this.seed,
    this.mediaService,
    this.pollInterval = const Duration(seconds: 5),
  });

  final String slug;
  final CommunityChatSeed? seed;
  final MediaUploadService? mediaService;
  final Duration pollInterval;

  @override
  ConsumerState<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends ConsumerState<CommunityChatPage>
    with WidgetsBindingObserver {
  late final CommunityChatService _service = ref.read(
    communityChatServiceProvider,
  );
  MediaUploadService? _mediaInstance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _centerKey = const ValueKey<String>('community-chat-center');
  final List<MediaDraft> _drafts = [];
  Timer? _poll;

  CommunityChatInfo? _info;
  List<CommunityChatMessage> _messages = const [];

  /// First message of the "center" sliver: older pages grow above it, so
  /// prepending never moves what is on screen.
  String? _anchorId;
  var _hasMoreBefore = false;

  /// /changes cursor, always taken verbatim from the backend.
  var _lastVersion = 0;

  /// Highest seq acknowledged (watermark or last POST /read). Never lowered.
  var _readSeq = 0;

  /// New readable messages that arrived while scrolled up; marked read once
  /// the user reaches the bottom.
  int? _pendingReadSeq;

  /// Bumped by every full (re)load so stale responses are discarded.
  var _loadToken = 0;
  var _loading = true;
  var _loadingOlder = false;
  var _pollInFlight = false;
  var _sending = false;
  var _picking = false;
  var _accessLost = false;
  var _following = true;
  var _unseenNew = false;
  String? _errorTitle;
  String? _errorMessage;

  final Map<String, List<ChatMessageReactionSummary>> _pendingReactions = {};
  final Map<String, int> _reactionTokens = {};
  var _reactionSeq = 0;

  MediaUploadService get _media =>
      _mediaInstance ??= widget.mediaService ?? MediaUploadService();

  String get _slug => widget.slug;

  bool get _canWrite => _info?.writable == true && !_accessLost;

  int get _maxSeq => _messages.isEmpty ? 0 : _messages.last.seq;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _pollChanges();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  /// Keyboard or rotation: keep the latest message in view while following.
  @override
  void didChangeMetrics() {
    if (_following) _jumpToEnd(attempts: 2);
  }

  void _startPolling() {
    if (_accessLost || !mounted) return;
    _poll?.cancel();
    _poll = Timer.periodic(widget.pollInterval, (_) => _pollChanges());
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _errorTitle = null;
      _errorMessage = null;
    });
    try {
      final info = await _service.info(_slug);
      final page = await _service.latest(_slug);
      if (!mounted || token != _loadToken) return;
      _applyFullPage(info, page);
      setState(() => _loading = false);
      _following = true;
      _jumpToEnd();
      _markRead(_maxSeq);
    } on CommunityChatException catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        if (error.isForbidden) {
          _errorTitle = 'Ya no tienes acceso';
          _errorMessage = communityChatAccessLostCopy;
        } else if (error.isNotFound) {
          _errorTitle = 'Chat no disponible';
          _errorMessage = 'Esta comunidad o su chat no est\u00e1 disponible.';
        } else {
          _errorTitle = 'No pudimos abrir el chat';
          _errorMessage = 'Revisa tu conexi\u00f3n e int\u00e9ntalo de nuevo.';
        }
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loading = false;
        _errorTitle = 'No pudimos abrir el chat';
        _errorMessage = 'Revisa tu conexi\u00f3n e int\u00e9ntalo de nuevo.';
      });
    }
  }

  /// Replaces the transcript with a fresh latest page (initial load and
  /// resync). Composer text, drafts and pending reactions are kept.
  void _applyFullPage(CommunityChatInfo info, CommunityChatMessagePage page) {
    setState(() {
      _info = info;
      _messages = mergeCommunityMessages(const [], page.items);
      _anchorId = _messages.isEmpty ? null : _messages.first.id;
      _hasMoreBefore = page.hasMoreBefore;
      _lastVersion = page.syncVersion;
      _readSeq = math.max(_readSeq, info.watermark);
      _pendingReadSeq = null;
      _unseenNew = false;
      _loadingOlder = false;
    });
  }

  /// One polling cycle: /changes from the stored cursor, repeated while the
  /// backend reports `hasMore` (bounded). Never overlaps itself or a reload.
  Future<void> _pollChanges() async {
    if (!mounted || _pollInFlight || _loading || _info == null || _accessLost) {
      return;
    }
    _pollInFlight = true;
    final token = _loadToken;
    try {
      for (var page = 0; page < communityChatMaxChangePages; page++) {
        final changes = await _service.changes(
          _slug,
          sinceVersion: _lastVersion,
        );
        if (!mounted || _accessLost || token != _loadToken) return;
        if (changes.resyncRequired) {
          await _resync();
          return;
        }
        _applyChanges(changes);
        if (!changes.hasMore) return;
      }
    } on CommunityChatException catch (error) {
      if (error.isForbidden || error.isNotFound) _onAccessLost();
      // Network / 5xx: keep the timeline, the next tick retries silently.
    } catch (_) {
      // Keep the open timeline if a refresh fails.
    } finally {
      _pollInFlight = false;
    }
  }

  /// `resyncRequired`: controlled reload of info + latest page (no loop: the
  /// cursor becomes the fresh syncVersion; a failure waits for the next tick).
  Future<void> _resync() async {
    final token = ++_loadToken;
    final previousMax = _maxSeq;
    final info = await _service.info(_slug);
    final page = await _service.latest(_slug);
    if (!mounted || token != _loadToken || _accessLost) return;
    _applyFullPage(info, page);
    _following = true;
    _jumpToEnd();
    final freshFromOthers = _messages.any(
      (message) =>
          message.seq > previousMax && message.isVisible && !message.mine,
    );
    if (freshFromOthers) _markRead(_maxSeq);
  }

  /// Applies a /changes page keyed by message id. Known ids update in place
  /// (reactions, tombstones): no scroll, no pill, no mark-read. Unknown ids
  /// with a new seq are new messages.
  void _applyChanges(CommunityChatChanges changes) {
    final known = {for (final message in _messages) message.id: message};
    final maxSeq = _maxSeq;
    final oldestSeq = _messages.isEmpty ? null : _messages.first.seq;
    final accepted = <CommunityChatMessage>[];
    var added = false;
    var addedReadable = false;
    for (final item in changes.items) {
      final current = known[item.id];
      if (current != null) {
        if (item.version >= current.version) accepted.add(item);
        continue;
      }
      // Older history not loaded yet: the page load will bring it.
      if (_hasMoreBefore && oldestSeq != null && item.seq < oldestSeq) {
        continue;
      }
      accepted.add(item);
      if (item.seq > maxSeq) {
        added = true;
        if (item.isVisible && !item.mine) addedReadable = true;
      }
    }
    final wasFollowing = _isNearBottom();
    setState(() {
      _lastVersion = changes.lastVersion;
      if (accepted.isNotEmpty) {
        _messages = mergeCommunityMessages(_messages, accepted);
        _anchorId ??= _messages.isEmpty ? null : _messages.first.id;
      }
      if (added && !wasFollowing) _unseenNew = true;
    });
    if (!added) return;
    if (wasFollowing) {
      _animateToEnd();
      if (addedReadable) _markRead(_maxSeq);
    } else if (addedReadable) {
      _pendingReadSeq = math.max(_pendingReadSeq ?? 0, _maxSeq);
    }
  }

  void _onAccessLost() {
    if (!mounted || _accessLost) return;
    _stopPolling();
    setState(() {
      _accessLost = true;
      _pendingReactions.clear();
      _reactionTokens.clear();
    });
  }

  /// POST /read with a monotonic seq: never at or below what the backend
  /// already has (watermark) or what this screen already sent.
  Future<void> _markRead(int seq) async {
    if (seq <= _readSeq || _accessLost || !mounted) return;
    final previous = _readSeq;
    _readSeq = seq;
    try {
      await _service.markRead(_slug, seq);
    } catch (_) {
      // Allow a later retry with the same seq; never go backwards.
      if (_readSeq == seq) _readSeq = previous;
    }
  }

  void _flushPendingRead() {
    final pending = _pendingReadSeq;
    if (pending == null) return;
    _pendingReadSeq = null;
    _markRead(pending);
  }

  /// Previous page (`beforeSeq` = oldest loaded seq). Single flight; stops
  /// when the backend reports `hasMoreBefore=false`.
  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreBefore || _loading || _messages.isEmpty) {
      return;
    }
    final token = _loadToken;
    final beforeSeq = _messages.first.seq;
    setState(() => _loadingOlder = true);
    try {
      final page = await _service.older(_slug, beforeSeq: beforeSeq);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _messages = mergeCommunityMessages(_messages, page.items);
        _hasMoreBefore = page.hasMoreBefore;
      });
    } on CommunityChatException catch (error) {
      if (error.isForbidden) _onAccessLost();
    } catch (_) {
      // Retried on the next scroll near the top.
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _following = _isNearBottom();
    if (_following) {
      if (_unseenNew) setState(() => _unseenNew = false);
      _flushPendingRead();
    }
    final position = _scroll.position;
    if (position.pixels - position.minScrollExtent <=
        communityChatOlderThreshold) {
      _loadOlder();
    }
  }

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    final position = _scroll.position;
    return position.maxScrollExtent - position.pixels <= chatFollowThreshold;
  }

  /// Jumps to the newest message. Lazily built rows can grow the extent after
  /// the first jump, so it re-checks for a few frames.
  void _jumpToEnd({int attempts = 4}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.maxScrollExtent - position.pixels > 0.5) {
        _scroll.jumpTo(position.maxScrollExtent);
        if (attempts > 1) _jumpToEnd(attempts: attempts - 1);
      }
      _following = true;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _animateToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _jumpToEnd(attempts: 3);
        return;
      }
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      if (mounted) _jumpToEnd(attempts: 2);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _openNewMessages() {
    setState(() => _unseenNew = false);
    _flushPendingRead();
    _animateToEnd();
  }

  bool get _uploading => _drafts.any(
    (draft) =>
        draft.state != MediaUploadState.ready &&
        draft.state != MediaUploadState.failed,
  );

  List<MediaDraft> get _readyDrafts =>
      _drafts.where((draft) => draft.isReady && draft.assetId != null).toList();

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send() async {
    if (!_canWrite || _sending || _uploading) return;
    if (_drafts.any((draft) => draft.state == MediaUploadState.failed)) {
      _snack('Una foto no se pudo subir. Qu\u00edtala o vuelve a intentarlo.');
      return;
    }
    final text = _input.text.trim();
    final ready = _readyDrafts;
    if (text.isEmpty && ready.isEmpty) return;
    if (text.length > chatMessageMaxLength) {
      _snack('El mensaje supera los $chatMessageMaxLength caracteres.');
      return;
    }
    setState(() => _sending = true);
    try {
      final message = await _service.send(
        _slug,
        text,
        mediaAssetIds: ready.map((draft) => draft.assetId!).toList(),
      );
      if (!mounted) return;
      _input.clear();
      setState(() {
        _messages = mergeCommunityMessages(_messages, [message]);
        _anchorId ??= message.id;
        _drafts.clear();
        _sending = false;
        _unseenNew = false;
      });
      _following = true;
      _animateToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack('No pudimos enviar el mensaje');
      if (error is CommunityChatException && error.isForbidden) {
        _recheckAccess();
      }
    }
  }

  /// A 403 on a write means the chat became read-only or the membership
  /// ended: the chat info tells which one.
  Future<void> _recheckAccess() async {
    try {
      final info = await _service.info(_slug);
      if (mounted) setState(() => _info = info);
    } on CommunityChatException catch (error) {
      if (error.isForbidden || error.isNotFound) _onAccessLost();
    } catch (_) {
      // Keep the current state; polling will tell.
    }
  }

  Future<void> _pickPhotos() async {
    if (_picking || !_canWrite || _drafts.length >= chatMaxImages) return;
    setState(() => _picking = true);
    try {
      await pickAndUploadChatImages(
        media: _media,
        drafts: _drafts,
        update: (change) {
          if (mounted) setState(change);
        },
      );
    } catch (_) {
      _snack('No pudimos adjuntar las fotos');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool get _canReact => _canWrite;

  List<ChatMessageReactionSummary> _reactionsOf(CommunityChatMessage message) =>
      _pendingReactions[message.id] ?? message.reactions;

  Future<void> _openReactions(
    BuildContext bubbleContext,
    CommunityChatMessage message,
  ) async {
    if (!_canReact || !message.isVisible || message.id.isEmpty) return;
    final box = bubbleContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    HapticFeedback.selectionClick();
    final selected = await showChatReactionPicker(
      context,
      anchor: anchor,
      alignEnd: message.mine,
      current: myChatReaction(_reactionsOf(message)),
    );
    if (selected == null || !mounted || !_canReact) return;
    await _react(message, selected, anchor);
  }

  /// Optimistic toggle (private chat UX): the same reaction removes it
  /// (DELETE), another one replaces it (PUT). Success reconciles with the
  /// response (reactions + message version); failure rolls back + snackbar.
  Future<void> _react(
    CommunityChatMessage message,
    ReactionType type,
    Rect anchor,
  ) async {
    final id = message.id;
    final current = _reactionsOf(message);
    final removing = myChatReaction(current) == type.apiValue;
    final token = ++_reactionSeq;
    setState(() {
      _reactionTokens[id] = token;
      _pendingReactions[id] = withMyChatReaction(
        current,
        removing ? null : type.apiValue,
      );
    });
    if (!removing && type == ReactionType.garra) {
      showChatGarraPulse(
        context,
        Offset(
          message.mine ? anchor.right - 24 : anchor.left + 24,
          anchor.bottom,
        ),
      );
    }
    try {
      final result = removing
          ? await _service.removeReaction(_slug, id)
          : await _service.react(_slug, id, type);
      if (!mounted || _reactionTokens[id] != token) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            m.id == id
                ? m.copyWith(
                    reactions: result.reactions,
                    myReaction: result.myReaction,
                    clearMyReaction: result.myReaction == null,
                    version: math.max(m.version, result.version),
                  )
                : m,
        ];
        _pendingReactions.remove(id);
        _reactionTokens.remove(id);
      });
    } catch (error) {
      if (!mounted || _reactionTokens[id] != token) return;
      setState(() {
        _pendingReactions.remove(id);
        _reactionTokens.remove(id);
      });
      _snack('No pudimos actualizar la reacci\u00f3n');
      if (error is CommunityChatException && error.isForbidden) {
        _recheckAccess();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.background,
      appBar: AppBar(titleSpacing: 0, title: _header()),
      body: ChatBackdrop(
        child: Column(
          children: [
            Expanded(child: _transcript()),
            if (_info != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  border: Border(
                    top: BorderSide(color: colors.border, width: 0.5),
                  ),
                ),
                child: SafeArea(top: false, child: _footer()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final colors = context.garraColors;
    final info = _info;
    final seedName = widget.seed?.name?.trim() ?? '';
    final infoName = info?.clanName.trim() ?? '';
    final name = infoName.isNotEmpty
        ? infoName
        : (seedName.isNotEmpty ? seedName : 'Chat de la comunidad');
    final count = info?.memberCount;
    final countLabel = count == null
        ? null
        : (count == 1 ? '1 miembro' : '$count miembros');
    return Semantics(
      key: const Key('community-chat-header'),
      header: true,
      label: countLabel == null
          ? 'Chat de $name'
          : 'Chat de $name, $countLabel',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            GarraAvatar(
              displayName: name,
              avatarUrl: widget.seed?.logoUrl,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    key: const Key('community-chat-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (countLabel != null)
                    Text(
                      countLabel,
                      key: const Key('community-chat-member-count'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transcript() {
    if (_loading && _info == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return GarraErrorState(
        title: _errorTitle ?? 'No pudimos abrir el chat',
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    if (_messages.isEmpty) {
      return GarraEmptyState(
        title: 'A\u00fan no hay mensajes',
        message: _canWrite
            ? 'Escribe el primer mensaje de la comunidad.'
            : 'Todav\u00eda no hay mensajes en este chat.',
      );
    }
    final entries = buildCommunityTimeline(
      _messages,
      groupBreakBeforeId: _anchorId,
    );
    var split = entries.indexWhere(
      (entry) =>
          entry is CommunityMessageEntry && entry.message.id == _anchorId,
    );
    // Whole history loaded from the anchor on: everything lives in the center
    // sliver (short chats render top-down with their first day label).
    // Otherwise the rows above the anchor (its day label included) belong to
    // the older sliver, which grows upwards, so the anchor row never moves.
    final complete = !_hasMoreBefore && _messages.first.id == _anchorId;
    if (split < 0 || complete) split = 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubble = math.min(constraints.maxWidth * 0.75, 480.0);
        Widget row(int index) =>
            _entryRow(entries, index, maxBubble, anchorRow: index == split);
        return Stack(
          children: [
            CustomScrollView(
              key: const Key('community-chat-transcript'),
              controller: _scroll,
              center: _centerKey,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
                if (_loadingOlder)
                  const SliverToBoxAdapter(
                    child: Padding(
                      key: Key('community-chat-older-loading'),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => row(split - 1 - index),
                      childCount: split,
                    ),
                  ),
                ),
                SliverPadding(
                  key: _centerKey,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => row(split + index),
                      childCount: entries.length - split,
                    ),
                  ),
                ),
              ],
            ),
            if (_unseenNew)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(child: _newMessagesPill()),
              ),
          ],
        );
      },
    );
  }

  Widget _entryRow(
    List<CommunityTimelineEntry> entries,
    int index,
    double maxBubble, {
    bool anchorRow = false,
  }) {
    final entry = entries[index];
    if (entry is CommunityDaySeparatorEntry) return _daySeparator(entry.label);
    final item = entry as CommunityMessageEntry;
    final previous = index > 0 ? entries[index - 1] : null;
    // The anchor row keeps a fixed gap whatever gets prepended above it.
    final topGap = anchorRow && index > 0
        ? 8.0
        : previous == null || previous is CommunityDaySeparatorEntry
        ? 0.0
        : (item.firstInGroup ? 8.0 : 2.0);
    return Padding(
      key: ValueKey<String>('community-chat-row-${item.message.id}'),
      padding: EdgeInsets.only(top: topGap),
      child: _messageRow(item, maxBubble),
    );
  }

  Widget _newMessagesPill() {
    final colors = context.garraColors;
    return Material(
      color: colors.brandPrimary,
      elevation: 2,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const Key('community-chat-new-messages-pill'),
        customBorder: const StadiumBorder(),
        onTap: _openNewMessages,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            'Nuevos mensajes \u2193',
            style: TextStyle(
              color: colors.onBrand,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _daySeparator(String label) {
    final colors = context.garraColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: DecoratedBox(
          key: const Key('community-chat-day-separator'),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Others: avatar + display name on the first bubble of a group, later
  /// bubbles indented under it. Own messages: right aligned, no identity.
  Widget _messageRow(CommunityMessageEntry entry, double maxBubble) {
    final message = entry.message;
    if (message.mine) {
      return Align(
        key: const Key('community-chat-bubble-mine'),
        alignment: Alignment.centerRight,
        child: _bubble(entry, maxBubble),
      );
    }
    final colors = context.garraColors;
    const avatarSize = 28.0;
    return Align(
      key: const Key('community-chat-bubble-other'),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: avatarSize,
            child: entry.firstInGroup
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GarraAvatar(
                      key: Key('community-chat-sender-avatar-${message.id}'),
                      displayName: message.sender.label,
                      avatarUrl: message.sender.avatarUrl,
                      size: avatarSize,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.firstInGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.sender.label,
                      key: Key('community-chat-sender-name-${message.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                _bubble(entry, maxBubble - avatarSize - 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BorderRadius _radius(CommunityMessageEntry entry) {
    const round = Radius.circular(18);
    const joined = Radius.circular(6);
    const tail = Radius.circular(4);
    return entry.message.mine
        ? BorderRadius.only(
            topLeft: round,
            bottomLeft: round,
            topRight: entry.firstInGroup ? round : joined,
            bottomRight: entry.lastInGroup ? tail : joined,
          )
        : BorderRadius.only(
            topRight: round,
            bottomRight: round,
            topLeft: entry.firstInGroup ? round : joined,
            bottomLeft: entry.lastInGroup ? tail : joined,
          );
  }

  Widget _tombstone(CommunityMessageEntry entry, double maxWidth) {
    final colors = context.garraColors;
    final message = entry.message;
    final label = message.isHiddenByModerator
        ? 'Mensaje retirado por moderaci\u00f3n'
        : 'Mensaje eliminado';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: Key('community-chat-tombstone-${message.id}'),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: _radius(entry),
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: message.mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.isHiddenByModerator
                      ? Icons.visibility_off_outlined
                      : Icons.block_outlined,
                  size: 14,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            if (entry.lastInGroup) _meta(message, colors.textSecondary, false),
          ],
        ),
      ),
    );
  }

  Widget _bubble(CommunityMessageEntry entry, double maxWidth) {
    final message = entry.message;
    if (message.isTombstone) return _tombstone(entry, maxWidth);
    final colors = context.garraColors;
    final mine = message.mine;
    final background = mine ? colors.brandPrimary : colors.surfaceRaised;
    final foreground = mine ? colors.onBrand : colors.textPrimary;
    final content = message.content ?? '';
    final hasText = content.trim().isNotEmpty;
    final images = message.media.where((item) => !item.isVideo).toList();
    final mediaOnly = !hasText && images.isNotEmpty;
    final reactions = _reactionsOf(message);
    final hasReactions = reactions.any((r) => r.reactionType != null);
    final chipRoom = hasReactions ? 6.0 : 0.0;
    final canReact = _canReact && message.id.isNotEmpty;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: mediaOnly
          ? EdgeInsets.fromLTRB(4, 4, 4, 6 + chipRoom)
          : EdgeInsets.fromLTRB(12, 8, 12, 6 + chipRoom),
      decoration: BoxDecoration(
        color: background,
        borderRadius: _radius(entry),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: hasText ? 6 : 0),
              child: ChatMediaGrid(
                media: images,
                maxWidth: maxWidth - (mediaOnly ? 8 : 24),
              ),
            ),
          if (hasText)
            Text(
              content,
              style: TextStyle(color: foreground, fontSize: 15, height: 1.3),
            ),
          if (entry.lastInGroup) _meta(message, foreground, mediaOnly),
        ],
      ),
    );
    final interactive = Builder(
      builder: (bubbleContext) => Semantics(
        onLongPressHint: canReact ? 'Reaccionar al mensaje' : null,
        customSemanticsActions: canReact
            ? {
                const CustomSemanticsAction(
                  label: 'Reaccionar al mensaje',
                ): () =>
                    _openReactions(bubbleContext, message),
              }
            : null,
        child: GestureDetector(
          key: Key('community-chat-bubble-gesture-${message.id}'),
          behavior: HitTestBehavior.opaque,
          onLongPress: canReact
              ? () => _openReactions(bubbleContext, message)
              : null,
          child: bubble,
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: hasReactions ? 14 : 0),
          child: interactive,
        ),
        if (hasReactions)
          Positioned(
            bottom: 0,
            left: mine ? null : 12,
            right: mine ? 12 : null,
            child: ChatMessageReactionChips(
              messageId: message.id,
              reactions: reactions,
            ),
          ),
      ],
    );
  }

  /// Time only: the group chat has no sent/read receipts.
  Widget _meta(CommunityChatMessage message, Color foreground, bool mediaOnly) {
    final created = message.createdAt;
    if (created == null) return const SizedBox.shrink();
    final time = formatGarraMessageTime(created);
    return Padding(
      padding: EdgeInsets.only(top: 3, right: mediaOnly ? 6 : 0),
      child: Semantics(
        label: message.mine
            ? 'Tu mensaje, a las $time'
            : 'Mensaje de ${message.sender.label}, a las $time',
        excludeSemantics: true,
        child: Text(
          time,
          key: Key('community-chat-meta-${message.id}'),
          style: TextStyle(
            fontSize: 11,
            color: foreground.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    final colors = context.garraColors;
    if (_accessLost || !_canWrite) {
      final lost = _accessLost;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Semantics(
          liveRegion: true,
          child: Row(
            key: Key(
              lost ? 'community-chat-access-lost' : 'community-chat-readonly',
            ),
            children: [
              Icon(
                lost ? Icons.lock_outline : Icons.visibility_outlined,
                size: 18,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lost
                      ? communityChatAccessLostCopy
                      : communityChatReadOnlyCopy,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_drafts.isNotEmpty) _draftStrip(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                key: const Key('community-chat-attach-photo'),
                tooltip: 'Adjuntar foto',
                onPressed:
                    _drafts.length >= chatMaxImages || _sending || _picking
                    ? null
                    : _pickPhotos,
                color: colors.textSecondary,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              Expanded(
                child: TextField(
                  key: const Key('community-chat-composer'),
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: chatMessageMaxLength,
                  keyboardType: TextInputType.multiline,
                  autocorrect: true,
                  enableSuggestions: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) {
                        if (currentLength < chatCounterFromLength) return null;
                        return Text(
                          '$currentLength/$chatMessageMaxLength',
                          key: const Key('community-chat-composer-counter'),
                          style: TextStyle(
                            fontSize: 11,
                            color: currentLength >= chatMessageMaxLength
                                ? colors.danger
                                : colors.textSecondary,
                          ),
                        );
                      },
                  style: TextStyle(fontSize: 15, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Escribe a la comunidad...',
                    isDense: true,
                    filled: true,
                    fillColor: colors.surface,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (context, value, _) {
                  final hasContent =
                      value.text.trim().isNotEmpty || _readyDrafts.isNotEmpty;
                  final enabled =
                      _canWrite && !_sending && !_uploading && hasContent;
                  return IconButton(
                    key: const Key('community-chat-send'),
                    tooltip: 'Enviar',
                    onPressed: enabled ? _send : null,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.brandPrimary,
                      foregroundColor: colors.onBrand,
                      disabledBackgroundColor: colors.surfaceMuted,
                      disabledForegroundColor: colors.textSecondary,
                      fixedSize: const Size(40, 40),
                      minimumSize: const Size(40, 40),
                    ),
                    icon: _sending
                        ? SizedBox(
                            key: const Key('community-chat-send-progress'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textSecondary,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _draftStrip() {
    final colors = context.garraColors;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        itemCount: _drafts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final draft = _drafts[index];
          final failed = draft.state == MediaUploadState.failed;
          final busy = !draft.isReady && !failed;
          return Stack(
            children: [
              Semantics(
                image: true,
                label: failed
                    ? 'Foto ${index + 1}, no se pudo subir'
                    : 'Foto ${index + 1} adjunta',
                child: ClipRRect(
                  key: Key('community-chat-image-preview-$index'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: colors.surfaceMuted,
                    child: draft.localPath == null
                        ? Icon(
                            Icons.image_outlined,
                            color: colors.textSecondary,
                          )
                        : Image.file(
                            File(draft.localPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.image_outlined,
                              color: colors.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
              if (busy || failed)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColoredBox(
                      color: colors.mediaBackdrop.withValues(alpha: 0.45),
                      child: Center(
                        child: failed
                            ? Icon(Icons.error_outline, color: colors.danger)
                            : SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: draft.progress > 0
                                      ? draft.progress
                                      : null,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -8,
                top: -8,
                child: IconButton(
                  key: Key('community-chat-image-remove-$index'),
                  tooltip: 'Quitar',
                  onPressed: _sending
                      ? null
                      : () => setState(() => _drafts.removeAt(index)),
                  icon: const Icon(Icons.cancel, size: 18),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
