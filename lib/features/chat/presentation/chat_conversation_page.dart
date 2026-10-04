import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/navigation/draft_exit_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/utils/garra_message_time.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_stickers.dart';
import '../../community/data/reaction_type.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/chat_image_uploads.dart';
import '../data/chat_models.dart';
import '../data/chat_service.dart';
import 'chat_backdrop.dart';
import 'chat_audio_composer.dart';
import 'chat_media_grid.dart';
import 'chat_message_reactions.dart';
import 'chat_request_copy.dart';
import 'chat_timeline.dart';
import 'chat_unread_badge.dart';
import 'chat_linked_text.dart';
import 'chat_reply_tile.dart';
import 'chat_swipe_to_reply.dart';

/// Distance to the bottom (px) that still counts as following the thread.
const double chatFollowThreshold = 120;

/// Backend limit for a message body.
const int chatMessageMaxLength = 1000;

/// The composer counter only appears close to the limit.
const int chatCounterFromLength = 850;

/// CHAT_V2_A: canonical screen for a conversation (`/chat/:conversationId`).
class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.conversationId,
    this.chatService,
    this.mediaService,
    this.pollInterval = const Duration(seconds: 5),
    this.requestJustSent = false,
  });

  final String conversationId;
  final ChatService? chatService;
  final MediaUploadService? mediaService;
  final Duration pollInterval;
  final bool requestJustSent;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage>
    with WidgetsBindingObserver {
  late final ChatService _chat = widget.chatService ?? ChatService();
  MediaUploadService? _mediaInstance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<MediaDraft> _drafts = [];
  final CancelToken _uploadCancelToken = CancelToken();
  Timer? _poll;
  ChatConversation? _conversation;
  ChatMessage? _editing;
  String? _beforeEdit;
  ChatReplyPreview? _replyTo;
  List<ChatMessage> _messages = const [];
  var _loading = true;
  var _sending = false;
  var _picking = false;
  final _exitGuard = DraftExitGuard();
  bool _completed = false;
  bool _audioDirty = false;
  bool get _dirty =>
      !_completed &&
      (_input.text.trim().isNotEmpty ||
          _drafts.isNotEmpty ||
          _audioDirty ||
          _replyTo != null ||
          _editing != null);
  void _leave() => _exitGuard.leave(
    context,
    dirty: _dirty,
    busy: _sending || _picking || _uploading,
    refresh: () => setState(() {}),
    pop: () => Navigator.of(context).pop(),
  );
  var _following = true;
  var _unseenNew = false;
  String? _error;

  /// CHAT_REACTIONS_13: optimistic reactions per message while its request is
  /// in flight. Polling updates [_messages] but never overrides these; only
  /// the latest request per message (token) resolves or rolls back.
  final Map<String, List<ChatMessageReactionSummary>> _pendingReactions = {};
  final Map<String, int> _reactionTokens = {};
  var _reactionSeq = 0;

  MediaUploadService get _media =>
      _mediaInstance ??= widget.mediaService ?? MediaUploadService();

  @override
  void initState() {
    super.initState();
    _input.addListener(_onDraftChanged);
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _input.removeListener(_onDraftChanged);
    _uploadCancelToken.cancel();
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _refresh();
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
    _poll?.cancel();
    _poll = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// The Home bell badge comes from GET /home/me and the Mensajes badge from
  /// GET /chat/unread-count. Marking a conversation read also clears its chat
  /// notifications server-side, so reload both once per successful mark-read.
  void _refreshHomeBadge() {
    if (!mounted) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.invalidate(homeProvider);
      container.invalidate(chatUnreadCountProvider);
    } on StateError {
      // No ProviderScope above this page (isolated widget tests).
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversation = await _chat.conversation(widget.conversationId);
      final messages = await _chat.messages(widget.conversationId);
      await _chat.markRead(widget.conversationId);
      _refreshHomeBadge();
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _messages = messages;
        _loading = false;
        _unseenNew = false;
      });
      _following = true;
      _jumpToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos abrir la conversaci\u00f3n';
        _loading = false;
      });
    }
  }

  /// Polling diff. A: new messages (may scroll when following, else show the
  /// "Nuevos mensajes" pill; the existing /read call runs once). B: only read
  /// receipts changed (false -> true): repaint, never scroll, never mark read.
  /// C: only reactions changed: repaint the bubbles, never scroll, no pill,
  /// never mark read (a reaction is not a new message).
  var _refreshing = false;

  Future<void> _refresh() async {
    // A slow network must not pile up one request pair per poll tick.
    if (!mounted || _sending || _refreshing) return;
    _refreshing = true;
    try {
      final conversation = await _chat.conversation(widget.conversationId);
      final messages = await _chat.messages(widget.conversationId);
      if (!mounted) return;
      final previousIds = {for (final message in _messages) message.id};
      final added = messages
          .where((message) => !previousIds.contains(message.id))
          .toList();
      final structureChanged =
          added.isNotEmpty || messages.length != _messages.length;
      final readChanged = !structureChanged && _readFlagsChanged(messages);
      final reactionsChanged = !structureChanged && _reactionsChanged(messages);
      final detailsChanged = !structureChanged && _detailsChanged(messages);
      final statusChanged = conversation.status != _conversation?.status;
      if (!structureChanged &&
          !readChanged &&
          !reactionsChanged &&
          !detailsChanged &&
          !statusChanged &&
          _conversation != null) {
        return;
      }
      final wasFollowing = _isNearBottom();
      setState(() {
        _conversation = conversation;
        _messages = messages;
        if (added.isNotEmpty && !wasFollowing) _unseenNew = true;
      });
      if (added.isNotEmpty) {
        if (wasFollowing) _animateToEnd();
        await _chat.markRead(widget.conversationId);
        _refreshHomeBadge();
      }
    } catch (_) {
      // Keep the open transcript if a refresh fails.
    } finally {
      _refreshing = false;
    }
  }

  bool _readFlagsChanged(List<ChatMessage> next) {
    for (var i = 0; i < next.length && i < _messages.length; i++) {
      if (next[i].id == _messages[i].id && next[i].read != _messages[i].read) {
        return true;
      }
    }
    return false;
  }

  bool _reactionsChanged(List<ChatMessage> next) {
    for (var i = 0; i < next.length && i < _messages.length; i++) {
      if (next[i].id == _messages[i].id &&
          next[i].reactionSignature != _messages[i].reactionSignature) {
        return true;
      }
    }
    return false;
  }

  bool _detailsChanged(List<ChatMessage> next) {
    for (var i = 0; i < next.length && i < _messages.length; i++) {
      final old = _messages[i];
      final fresh = next[i];
      if (old.id != fresh.id ||
          old.content != fresh.content ||
          old.editedAt != fresh.editedAt ||
          old.deleted != fresh.deleted ||
          old.replyTo?.content != fresh.replyTo?.content ||
          old.replyTo?.deleted != fresh.replyTo?.deleted) {
        return true;
      }
    }
    return false;
  }

  void _startReply(ChatMessage message) {
    if (message.deleted) return;
    _cancelEdit();
    setState(
      () => _replyTo = ChatReplyPreview(
        id: message.id,
        senderId: message.senderId,
        senderName: message.mine
            ? 'Tú'
            : (_conversation?.otherDisplayName ?? 'Hincha'),
        content: message.content.trim().isEmpty ? 'Foto' : message.content,
      ),
    );
  }

  void _startEdit(ChatMessage message) {
    if (!message.mine || message.deleted || message.content.trim().isEmpty) {
      return;
    }
    if (_drafts.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Termina o quita las fotos antes de editar.'),
        ),
      );
      return;
    }
    _beforeEdit = _input.text;
    setState(() {
      _editing = message;
      _replyTo = null;
      _input.text = message.content;
    });
  }

  void _cancelEdit() {
    if (_editing == null) return;
    setState(() {
      _editing = null;
      _input.text = _beforeEdit ?? '';
      _beforeEdit = null;
    });
  }

  Future<void> _delete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar este mensaje?'),
        content: const Text('El mensaje dejará de mostrarse en el chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !allowNetworkAction(context)) return;
    try {
      final tombstone = await _chat.deleteMessage(message.id);
      if (mounted) {
        setState(
          () => _messages = [
            for (final row in _messages)
              row.id == message.id
                  ? tombstone
                  : row.replyTo?.id == message.id
                  ? row.copyWith(
                      replyTo: ChatReplyPreview(
                        id: message.id,
                        senderId: message.senderId,
                        senderName: message.mine
                            ? 'Tú'
                            : (_conversation?.otherDisplayName ?? 'Hincha'),
                        content: 'Mensaje eliminado',
                        deleted: true,
                      ),
                    )
                  : row,
          ],
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos eliminar el mensaje')),
        );
      }
    }
  }

  void _jumpToReply(String id) {
    final index = _messages.indexWhere((message) => message.id == id);
    if (index < 0 || !_scroll.hasClients) return;
    final contextOfTarget = _messageKeys[id]?.currentContext;
    if (contextOfTarget != null) {
      Scrollable.ensureVisible(
        contextOfTarget,
        duration: const Duration(milliseconds: 220),
      );
      return;
    }
    _scroll.animateTo(
      (index * 80.0).clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  final Map<String, GlobalKey> _messageKeys = {};

  Future<void> _accept() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final accepted = await _chat.accept(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = accepted;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos aceptar la solicitud')),
      );
    }
  }

  Future<void> _reject() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _chat.reject(widget.conversationId);
      if (!mounted) return;
      _completed = true;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos rechazar la solicitud')),
      );
    }
  }

  bool get _uploading => _drafts.any(
    (draft) =>
        draft.state != MediaUploadState.ready &&
        draft.state != MediaUploadState.failed,
  );

  List<MediaDraft> get _readyDrafts =>
      _drafts.where((draft) => draft.isReady && draft.assetId != null).toList();

  Future<void> _send() async {
    if (_sending || _uploading || _conversation?.status != 'ACTIVE') return;
    if (_drafts.any((draft) => draft.state == MediaUploadState.failed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reintenta o quita la foto con error.')),
      );
      return;
    }
    final text = _input.text.trim();
    final ready = _readyDrafts;
    if (text.isEmpty && (ready.isEmpty || _editing != null)) return;
    if (!allowNetworkAction(context)) return;
    setState(() => _sending = true);
    try {
      final editing = _editing;
      if (editing != null) {
        final updated = await _chat.editMessage(editing.id, text);
        if (!mounted) return;
        setState(() {
          _messages = [
            for (final row in _messages)
              row.id == updated.id
                  ? updated
                  : row.replyTo?.id == updated.id
                  ? row.copyWith(
                      replyTo: ChatReplyPreview(
                        id: updated.id,
                        senderId: updated.senderId,
                        senderName: updated.mine
                            ? 'Tú'
                            : (_conversation?.otherDisplayName ?? 'Hincha'),
                        content: updated.content,
                        deleted: false,
                      ),
                    )
                  : row,
          ];
          _editing = null;
          _beforeEdit = null;
          _sending = false;
          _input.clear();
        });
        return;
      }
      final message = _replyTo == null
          ? await _chat.send(
              widget.conversationId,
              text,
              mediaAssetIds: ready.map((draft) => draft.assetId!).toList(),
            )
          : await _chat.sendReply(
              widget.conversationId,
              text,
              _replyTo!.id,
              mediaAssetIds: ready.map((draft) => draft.assetId!).toList(),
            );
      if (!mounted) return;
      _input.clear();
      setState(() {
        _messages = [..._messages, message];
        _drafts.clear();
        _replyTo = null;
        _sending = false;
        _unseenNew = false;
      });
      _following = true;
      _animateToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos enviar el mensaje')),
      );
    }
  }

  Future<void> _sendAudio(String assetId, int durationSeconds) async {
    if (_sending || _conversation?.status != 'ACTIVE') return;
    if (!allowNetworkAction(context)) throw StateError('Offline');
    setState(() => _sending = true);
    try {
      final message = await _chat.sendAudio(widget.conversationId,
          assetId, durationSeconds);
      if (!mounted) return;
      setState(() { _messages = [..._messages, message]; _sending = false; });
      _following = true;
      _animateToEnd();
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      rethrow;
    }
  }

  Future<void> _pickPhotos() async {
    if (_picking || _drafts.length >= chatMaxImages) return;
    setState(() => _picking = true);
    try {
      await pickAndUploadChatImages(
        media: _media,
        drafts: _drafts,
        canUpload: () => mounted && allowNetworkAction(context),
        cancelToken: _uploadCancelToken,
        update: (change) {
          if (mounted) setState(change);
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos adjuntar las fotos')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _following = _isNearBottom();
    if (_following && _unseenNew) setState(() => _unseenNew = false);
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
    _animateToEnd();
  }

  bool get _canReact => _conversation?.status == 'ACTIVE';

  List<ChatMessageReactionSummary> _reactionsOf(ChatMessage message) =>
      _pendingReactions[message.id] ?? message.reactions;

  Future<void> _openReactions(
    BuildContext bubbleContext,
    ChatMessage message,
  ) async {
    if (!_canReact || message.id.isEmpty) return;
    final box = bubbleContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    HapticFeedback.selectionClick();
    final selected = await showChatReactionPicker(
      context,
      anchor: anchor,
      alignEnd: message.mine,
      current: myChatReaction(_reactionsOf(message)),
      actions: [
        ChatMessageAction(
          key: const Key('chat-action-reply'),
          label: 'Responder',
          icon: Icons.reply,
          onSelected: () => _startReply(message),
        ),
        if (message.mine &&
            message.content.trim().isNotEmpty &&
            message.createdAt != null &&
            DateTime.now().difference(message.createdAt!).inMinutes < 15)
          ChatMessageAction(
            key: const Key('chat-action-edit'),
            label: 'Editar',
            icon: Icons.edit_outlined,
            onSelected: () => _startEdit(message),
          ),
        if (message.mine)
          ChatMessageAction(
            key: const Key('chat-action-delete'),
            label: 'Eliminar',
            icon: Icons.delete_outline,
            destructive: true,
            onSelected: () => _delete(message),
          ),
      ],
    );
    if (selected == null || !mounted || !_canReact) return;
    await _react(message, selected, anchor);
  }

  /// Optimistic toggle: the same reaction again removes it (DELETE), another
  /// one replaces it (PUT). Success reconciles with the small response; a
  /// failure rolls back to the last server state and shows a snackbar.
  Future<void> _react(
    ChatMessage message,
    ReactionType type,
    Rect anchor,
  ) async {
    if (!allowNetworkAction(context)) return;
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
          ? await _chat.removeMessageReaction(id)
          : await _chat.reactToMessage(id, type);
      if (!mounted || _reactionTokens[id] != token) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            m.id == id ? m.copyWith(reactions: result.reactions) : m,
        ];
        _pendingReactions.remove(id);
        _reactionTokens.remove(id);
      });
    } catch (_) {
      if (!mounted || _reactionTokens[id] != token) return;
      setState(() {
        _pendingReactions.remove(id);
        _reactionTokens.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos actualizar la reacci\u00f3n')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final colors = context.garraColors;
    return PopScope(
      canPop: _exitGuard.canPop(
        dirty: _dirty,
        busy: _sending || _picking || _uploading,
      ),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: colors.background,
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          titleSpacing: 0,
          title: conversation == null
              ? const Text('Mensajes')
              : _header(conversation),
        ),
        body: ChatBackdrop(
          child: Column(
            children: [
              if (conversation != null) _statusBanner(conversation),
              Expanded(child: _transcript()),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  border: Border(
                    top: BorderSide(color: colors.border, width: 0.5),
                  ),
                ),
                child: SafeArea(top: false, child: _footer(conversation)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ChatConversation conversation) {
    final colors = context.garraColors;
    final name = conversation.otherDisplayName;
    final listing = conversation.listingTitle?.trim() ?? '';
    final String? subtitle;
    if (conversation.context == 'MARKETPLACE' && listing.isNotEmpty) {
      subtitle = 'Marketplace \u00b7 $listing';
    } else if (conversation.otherUsername.trim().isNotEmpty) {
      subtitle = '@${conversation.otherUsername.trim()}';
    } else {
      subtitle = null;
    }
    return Semantics(
      button: true,
      label: 'Ver perfil de $name',
      child: InkWell(
        key: const Key('chat-header-profile'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/comunidad/u/${conversation.otherUserId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              GarraAvatar(
                displayName: name,
                avatarUrl: conversation.otherAvatarUrl,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        key: const Key('chat-header-subtitle'),
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
      ),
    );
  }

  Widget _statusBanner(ChatConversation conversation) {
    if (conversation.status != 'PENDING') return const SizedBox.shrink();
    final copy = ChatRequestCopy.resolve(conversation: conversation);
    final waiting = conversation.outgoing
        ? copy.pendingStatus
        : 'Solicitud de chat';
    return Material(
      key: const Key('chat-pending-banner'),
      color: context.garraColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GarraSpacing.lg,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.requestJustSent && conversation.outgoing) ...[
              Text(
                'Solicitud enviada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(copy.replyAfterAcceptance),
              const SizedBox(height: 8),
            ],
            Text(waiting),
          ],
        ),
      ),
    );
  }

  Widget _footer(ChatConversation? conversation) {
    final pendingIncoming =
        conversation?.status == 'PENDING' && conversation?.outgoing == false;
    if (pendingIncoming) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('chat-reject-request'),
                onPressed: _sending ? null : _reject,
                child: const Text('Rechazar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('chat-accept-request'),
                onPressed: _sending ? null : _accept,
                child: const Text('Aceptar'),
              ),
            ),
          ],
        ),
      );
    }
    final colors = context.garraColors;
    final canWrite = conversation?.status == 'ACTIVE';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editing != null)
            ListTile(
              dense: true,
              title: const Text('Editar mensaje'),
              trailing: IconButton(
                tooltip: 'Cancelar edición',
                onPressed: _cancelEdit,
                icon: const Icon(Icons.close),
              ),
            ),
          if (_replyTo != null)
            ChatReplyTile(
              reply: _replyTo!,
              onCancel: () => setState(() => _replyTo = null),
            ),
          if (_drafts.isNotEmpty) _draftStrip(),
          if (chatAudioEnabled && canWrite && _editing == null)
            Align(alignment: Alignment.centerLeft,
              child: ChatAudioComposer(onSend: _sendAudio, enabled: !_sending,
                  media: _media, onDirtyChanged: (dirty) {
                    if (mounted) setState(() => _audioDirty = dirty);
                  })),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (canWrite && _editing == null)
                IconButton(tooltip: 'Elegir sticker',
                  onPressed: () => insertGarraSticker(context, _input),
                  icon: const Icon(Icons.emoji_emotions_outlined)),
              if (canWrite && _editing == null)
                IconButton(
                  key: const Key('chat-attach-photo'),
                  tooltip: 'Adjuntar foto',
                  onPressed:
                      _drafts.length >= chatMaxImages || _sending || _picking
                      ? null
                      : _pickPhotos,
                  color: colors.textSecondary,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                )
              else
                const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  key: const Key('chat-composer'),
                  controller: _input,
                  enabled: canWrite,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: chatMessageMaxLength,
                  // Standard alphanumeric keyboard (the Gboard toolbar belongs
                  // to Android, not to the app); long text wraps up to 4 lines.
                  keyboardType: TextInputType.multiline,
                  autocorrect: true,
                  enableSuggestions: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: canWrite ? (_) => _send() : null,
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
                          key: const Key('chat-composer-counter'),
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
                    hintText: _editing != null
                        ? 'Editar mensaje...'
                        : canWrite
                        ? 'Escribe un mensaje...'
                        : ChatRequestCopy.resolve(
                            conversation: conversation,
                          ).blockedComposerHint(
                            pendingOutgoing:
                                conversation?.status == 'PENDING' &&
                                conversation?.outgoing == true,
                          ),
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
                      value.text.trim().isNotEmpty ||
                      (_editing == null && _readyDrafts.isNotEmpty);
                  // Disabled (visually and for semantics) until there is text
                  // or a ready photo; media-only messages can be sent. Stays
                  // disabled while a photo uploads or a message is sending.
                  final enabled =
                      canWrite && !_sending && !_uploading && hasContent;
                  return IconButton(
                    key: const Key('chat-send'),
                    tooltip: _editing == null ? 'Enviar' : 'Guardar edición',
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
                            key: const Key('chat-send-progress'),
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
              ClipRRect(
                key: Key('chat-image-preview-$index'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 64,
                  color: colors.surfaceMuted,
                  child: draft.localPath == null
                      ? Icon(Icons.image_outlined, color: colors.textSecondary)
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
              if (busy || failed)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColoredBox(
                      color: colors.mediaBackdrop.withValues(alpha: 0.45),
                      child: Center(
                        child: failed
                            ? IconButton(
                                tooltip: 'Reintentar foto',
                                icon: Icon(Icons.refresh, color: colors.danger),
                                onPressed: () => retryChatImage(
                                  media: _media,
                                  drafts: _drafts,
                                  failed: draft,
                                  update: (change) {
                                    if (mounted) setState(change);
                                  },
                                  canUpload: () =>
                                      mounted && allowNetworkAction(context),
                                  cancelToken: _uploadCancelToken,
                                ),
                              )
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

  Widget _transcript() {
    if (_loading) return const GarraConversationSkeleton();
    if (_error != null) {
      return GarraErrorState(message: _error!, onRetry: _load);
    }
    if (_messages.isEmpty) {
      return const GarraEmptyState(
        title: 'Conversaci\u00f3n lista',
        message: 'Escribe el primer mensaje.',
      );
    }
    final entries = buildChatTimeline(_messages);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubble = math.min(constraints.maxWidth * 0.75, 480.0);
        return Stack(
          children: [
            ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                if (entry is ChatDaySeparatorEntry) {
                  return _daySeparator(entry.label);
                }
                final item = entry as ChatMessageEntry;
                final previous = index > 0 ? entries[index - 1] : null;
                final topGap =
                    previous == null || previous is ChatDaySeparatorEntry
                    ? 0.0
                    : (item.firstInGroup ? 8.0 : 2.0);
                return Padding(
                  padding: EdgeInsets.only(top: topGap),
                  child: _bubble(item, maxBubble),
                );
              },
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

  Widget _newMessagesPill() {
    final colors = context.garraColors;
    return Material(
      color: colors.brandPrimary,
      elevation: 2,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const Key('chat-new-messages-pill'),
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
          key: const Key('chat-day-separator'),
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

  Widget _bubble(ChatMessageEntry entry, double maxWidth) {
    final colors = context.garraColors;
    final message = entry.message;
    if (message.deleted) {
      return Align(
        alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: Key('chat-tombstone-${message.id}'),
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.all(12),
          child: const Text('Mensaje eliminado'),
        ),
      );
    }
    final mine = message.mine;
    final background = mine ? colors.brandPrimary : colors.surfaceRaised;
    final foreground = mine ? colors.onBrand : colors.textPrimary;
    const round = Radius.circular(18);
    const joined = Radius.circular(6);
    const tail = Radius.circular(4);
    final radius = mine
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
    final hasText = message.content.trim().isNotEmpty;
    final images = message.media.where((item) => !item.isVideo).toList();
    final mediaOnly = !hasText && images.isNotEmpty;
    final reactions = _reactionsOf(message);
    final hasReactions = reactions.any((r) => r.reactionType != null);
    // Room so the chip overlapping the bottom edge never covers text or meta.
    final chipRoom = hasReactions ? 6.0 : 0.0;
    final canReact = _canReact && message.id.isNotEmpty;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: mediaOnly
          ? EdgeInsets.fromLTRB(4, 4, 4, 6 + chipRoom)
          : EdgeInsets.fromLTRB(12, 8, 12, 6 + chipRoom),
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.replyTo != null)
            ChatReplyTile(
              reply: message.replyTo!,
              onTap: () => _jumpToReply(message.replyTo!.id),
            ),
          if (images.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: hasText ? 6 : 0),
              child: ChatMediaGrid(
                media: images,
                maxWidth: maxWidth - (mediaOnly ? 8 : 24),
              ),
            ),
          if (GarraSticker.fromContent(message.content) case final sticker?)
            GarraStickerView(sticker: sticker, compact: true)
          else if (hasText)
            ChatLinkedText(
              message.content,
              style: TextStyle(color: foreground, fontSize: 15, height: 1.3),
            ),
          if (entry.lastInGroup) _meta(message, foreground, mediaOnly),
        ],
      ),
    );
    // CHAT_REACTIONS_13: long press on the whole bubble (text, photos, own or
    // other) opens the picker; taps still reach the photos (media viewer).
    final interactive = KeyedSubtree(
      key: _messageKeys.putIfAbsent(message.id, () => GlobalKey()),
      child: Builder(
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
          child: ChatSwipeToReply(
            key: Key('chat-bubble-gesture-${message.id}'),
            onReply: () => _startReply(message),
            onLongPress: canReact
                ? () => _openReactions(bubbleContext, message)
                : null,
            child: bubble,
          ),
        ),
      ),
    );
    return Align(
      key: Key(mine ? 'chat-bubble-mine' : 'chat-bubble-other'),
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Stack(
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
      ),
    );
  }

  /// "8:42 p. m. · Enviado" / "· Leído" on own messages; time only on others.
  Widget _meta(ChatMessage message, Color foreground, bool mediaOnly) {
    final created = message.createdAt;
    final time = created == null ? '' : formatGarraMessageTime(created);
    final status = message.mine
        ? (message.read ? 'Le\u00eddo' : 'Enviado')
        : null;
    final parts = [
      if (time.isNotEmpty) time,
      if (message.editedAt != null) 'editado',
      ?status,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    final semantics = message.mine
        ? '${status!}${time.isEmpty ? '' : ', enviado a las $time'}'
        : 'Recibido a las $time';
    return Padding(
      padding: EdgeInsets.only(top: 3, right: mediaOnly ? 6 : 0),
      child: Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Text(
          parts.join(' \u00b7 '),
          key: Key('chat-meta-${message.id}'),
          style: TextStyle(
            fontSize: 11,
            color: foreground.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}
