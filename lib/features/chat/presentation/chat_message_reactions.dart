import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../../community/data/reaction_type.dart';
import '../../community/presentation/widgets/garra_comment_reactions.dart';
import '../data/chat_models.dart';

/// CHAT_REACTIONS_13: compact private-chat subset of the global catalog, in
/// picker order. ANGER and CARE are never offered in chat.
const List<ReactionType> chatReactionTypes = [
  ReactionType.like,
  ReactionType.love,
  ReactionType.haha,
  ReactionType.fire,
  ReactionType.garra,
  ReactionType.sad,
];

/// Touch target of one picker option (>= 44dp).
const double chatReactionOptionExtent = 44;

/// Icon size inside the picker.
const double chatReactionPickerIconSize = 28;

const double _pickerPadding = 6;

/// Width / height of the floating picker pill.
const double chatReactionPickerWidth =
    chatReactionOptionExtent * 6 + _pickerPadding * 2;
const double chatReactionPickerHeight =
    chatReactionOptionExtent + _pickerPadding * 2;

/// Duration of the compact GARRA micro-animation in chat.
const Duration chatGarraPulseDuration = Duration(milliseconds: 320);

/// Glyph size of the compact GARRA micro-animation.
const double chatGarraPulseSize = 36;

/// Chips order: most reacted first, then chat picker order, then catalog.
List<ChatMessageReactionSummary> sortedChatReactions(
  List<ChatMessageReactionSummary> reactions,
) {
  int rank(String type) {
    final parsed = ReactionType.tryParse(type);
    final chatIndex = parsed == null ? -1 : chatReactionTypes.indexOf(parsed);
    if (chatIndex >= 0) return chatIndex;
    return chatReactionTypes.length + (parsed?.index ?? 99);
  }

  final visible = reactions.where((r) => r.reactionType != null).toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return rank(a.type).compareTo(rank(b.type));
    });
  return visible;
}

/// Spanish accessibility label of one reaction chip segment.
String chatReactionChipLabel(ChatMessageReactionSummary reaction) {
  final label = ReactionType.labelFor(reaction.type);
  final count = reaction.count == 1
      ? '1 reacci\u00f3n'
      : '${reaction.count} reacciones';
  final base = '$label, $count';
  return reaction.reactedByMe ? '$base. Tu reacci\u00f3n: $label' : base;
}

/// Read-only reaction chips shown on a message (posts' picker is not reused:
/// chat shows every type separately with its count). Renders nothing when
/// there are no reactions. The viewer's reaction gets a soft tint, a border
/// and a bolder count (not color only) and is marked as selected.
class ChatMessageReactionChips extends StatelessWidget {
  const ChatMessageReactionChips({
    super.key,
    required this.messageId,
    required this.reactions,
  });

  final String messageId;
  final List<ChatMessageReactionSummary> reactions;

  @override
  Widget build(BuildContext context) {
    final visible = sortedChatReactions(reactions);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final colors = context.garraColors;
    final Widget content = visible.isEmpty
        ? const SizedBox.shrink()
        : DecoratedBox(
            key: Key('chat-reactions-$messageId'),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    _ReactionChipSegment(
                      messageId: messageId,
                      reaction: visible[i],
                    ),
                  ],
                ],
              ),
            ),
          );
    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      child: content,
    );
  }
}

class _ReactionChipSegment extends StatelessWidget {
  const _ReactionChipSegment({required this.messageId, required this.reaction});

  final String messageId;
  final ChatMessageReactionSummary reaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final type = reaction.reactionType!;
    final mine = reaction.reactedByMe;
    final accent = commentReactionAccent(context);
    return Semantics(
      container: true,
      label: chatReactionChipLabel(reaction),
      selected: mine,
      excludeSemantics: true,
      child: DecoratedBox(
        key: Key('chat-reaction-chip-$messageId-${reaction.type}'),
        decoration: BoxDecoration(
          color: mine ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: mine ? accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CommentReactionIcon(type: type, size: 14),
              const SizedBox(width: 3),
              Text(
                '${reaction.count}',
                key: Key('chat-reaction-count-$messageId-${reaction.type}'),
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: colors.textPrimary,
                  fontWeight: mine ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact horizontal picker with the six chat reactions (exact order:
/// LIKE, LOVE, HAHA, FIRE, GARRA, SAD). Reuses the social glyphs, tints and
/// Spanish labels. [selected] is the viewer's current reaction (API value).
class ChatReactionPicker extends StatelessWidget {
  const ChatReactionPicker({
    super.key,
    this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<ReactionType> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final current = ReactionType.tryParse(selected);
    return Semantics(
      container: true,
      label: 'Reacciones',
      child: Material(
        key: const Key('chat-reaction-picker'),
        color: colors.surfaceRaised,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: StadiumBorder(side: BorderSide(color: colors.border)),
        child: Padding(
          padding: const EdgeInsets.all(_pickerPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final type in chatReactionTypes)
                _ChatReactionOption(
                  type: type,
                  selected: current == type,
                  onTap: () => onSelected(type),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatReactionOption extends StatelessWidget {
  const _ChatReactionOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ReactionType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = commentReactionTint(context, type);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: type.labelEs,
      excludeSemantics: true,
      child: Tooltip(
        message: type.labelEs,
        excludeFromSemantics: true,
        child: InkResponse(
          key: Key('chat-reaction-option-${type.apiValue}'),
          onTap: onTap,
          radius: chatReactionOptionExtent / 2,
          child: SizedBox.square(
            dimension: chatReactionOptionExtent,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? tint.withValues(alpha: 0.16)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected ? tint : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: CommentReactionIcon(
                    type: type,
                    size: chatReactionPickerIconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the floating picker next to [anchor] (the message bubble, global
/// coordinates). Shown above the bubble, or below it when there is no room
/// near the top; aligned to the bubble side ([alignEnd] for own messages) and
/// kept on screen. Tapping outside or system back closes it (returns null).
///
/// [actions] (COMMUNITY_GROUP_CHAT_14C) adds contextual message actions in a
/// separate row next to the reactions (never inside the emoji row). Picking
/// one closes the picker (returns null) and then runs its callback. Empty by
/// default: the private chat picker is unchanged.
Future<ReactionType?> showChatReactionPicker(
  BuildContext context, {
  required Rect anchor,
  required bool alignEnd,
  String? current,
  List<ChatMessageAction> actions = const [],
}) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  if (actions.isNotEmpty) {
    return showModalBottomSheet<ReactionType>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 420),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatReactionPicker(
                selected: current,
                onSelected: (type) {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop(type);
                },
              ),
              const SizedBox(height: 12),
              _ChatMessageActionsBar(
                actions: actions,
                onTap: (action) {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop();
                  action.onSelected();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  return Navigator.of(context, rootNavigator: true).push<ReactionType>(
    _ChatReactionPickerRoute(
      anchor: anchor,
      alignEnd: alignEnd,
      current: current,
      reduceMotion: reduceMotion,
      actions: actions,
    ),
  );
}

/// COMMUNITY_GROUP_CHAT_14C: a contextual action shown under/over the
/// reaction picker (e.g. "Eliminar", "Retirar mensaje").
class ChatMessageAction {
  const ChatMessageAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final Key key;
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;
}

/// Height of the contextual actions row.
const double chatMessageActionsHeight = 48;

class _ChatMessageActionsBar extends StatelessWidget {
  const _ChatMessageActionsBar({required this.actions, required this.onTap});

  final List<ChatMessageAction> actions;
  final ValueChanged<ChatMessageAction> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Material(
      key: const Key('chat-message-actions'),
      color: colors.surfaceRaised,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            Semantics(
              button: true,
              label: action.label,
              excludeSemantics: true,
              child: InkWell(
                key: action.key,
                onTap: () => onTap(action),
                child: SizedBox(
                  height: chatMessageActionsHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          action.icon,
                          size: 20,
                          color: action.destructive
                              ? colors.danger
                              : colors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          action.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: action.destructive
                                ? colors.danger
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Picker position for [anchor] inside a screen of [size] with [padding].
@visibleForTesting
Offset chatReactionPickerOrigin({
  required Rect anchor,
  required bool alignEnd,
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  const gap = 8.0;
  const margin = 8.0;
  final maxLeft = size.width - chatReactionPickerWidth - margin;
  final rawLeft = alignEnd
      ? anchor.right - chatReactionPickerWidth
      : anchor.left;
  final left = maxLeft < margin ? margin : rawLeft.clamp(margin, maxLeft);
  final minTop = padding.top + margin;
  final maxTop =
      size.height - padding.bottom - chatReactionPickerHeight - margin;
  var top = anchor.top - chatReactionPickerHeight - gap;
  if (top < minTop) top = anchor.bottom + gap;
  if (maxTop >= minTop) top = top.clamp(minTop, maxTop);
  return Offset(left.toDouble(), top);
}

class _ChatReactionPickerRoute extends PopupRoute<ReactionType> {
  _ChatReactionPickerRoute({
    required this.anchor,
    required this.alignEnd,
    required this.current,
    required this.reduceMotion,
    this.actions = const [],
  });

  final Rect anchor;
  final bool alignEnd;
  final String? current;
  final bool reduceMotion;
  final List<ChatMessageAction> actions;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Cerrar reacciones';

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 160);

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final origin = chatReactionPickerOrigin(
      anchor: anchor,
      alignEnd: alignEnd,
      size: media.size,
      padding: media.padding,
    );
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    if (actions.isNotEmpty) {
      return _buildWithActions(context, media, origin, curved);
    }
    return Stack(
      children: [
        Positioned(
          left: origin.dx,
          top: origin.dy,
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
              alignment: alignEnd
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: ChatReactionPicker(
                selected: current,
                onSelected: (type) {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(type);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reactions plus the contextual actions row: the actions sit on the far
  /// side of the bubble (above the picker when it opens above, below when it
  /// opens below) and the whole block stays on screen.
  Widget _buildWithActions(
    BuildContext context,
    MediaQueryData media,
    Offset origin,
    Animation<double> curved,
  ) {
    const gap = 6.0;
    const margin = 8.0;
    final extra = actions.length * chatMessageActionsHeight + gap;
    final above = origin.dy < anchor.top;
    final minTop = media.padding.top + margin;
    final maxTop =
        media.size.height -
        media.padding.bottom -
        chatReactionPickerHeight -
        extra -
        margin;
    var top = above ? origin.dy - extra : origin.dy;
    if (maxTop >= minTop) top = top.clamp(minTop, maxTop);
    final picker = ChatReactionPicker(
      selected: current,
      onSelected: (type) {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop(type);
      },
    );
    final bar = _ChatMessageActionsBar(
      actions: actions,
      onTap: (action) {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        action.onSelected();
      },
    );
    return Stack(
      children: [
        Positioned(
          left: origin.dx,
          top: top,
          width: chatReactionPickerWidth,
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
              alignment: alignEnd
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: alignEnd
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: above
                    ? [bar, const SizedBox(height: gap), picker]
                    : [picker, const SizedBox(height: gap), bar],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Compact GARRA micro-animation for chat (~320ms, 36px, short rise) at
/// [center] (global coordinates). Pointer-transparent, never blocks the
/// thread, skipped when the platform asks to reduce motion. Only GARRA gets
/// it; other reactions use the chips' size animation + haptics.
void showChatGarraPulse(BuildContext context, Offset center) {
  final media = MediaQuery.maybeOf(context);
  if (media?.disableAnimations ?? false) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final color = commentReactionTint(context, ReactionType.garra);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ChatGarraPulse(
      center: center,
      color: color,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _ChatGarraPulse extends StatefulWidget {
  const _ChatGarraPulse({
    required this.center,
    required this.color,
    required this.onDone,
  });

  final Offset center;
  final Color color;
  final VoidCallback onDone;

  @override
  State<_ChatGarraPulse> createState() => _ChatGarraPulseState();
}

class _ChatGarraPulseState extends State<_ChatGarraPulse>
    with SingleTickerProviderStateMixin {
  static const double _rise = 14;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: chatGarraPulseDuration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = t < 0.5
            ? 0.6 + 0.55 * Curves.easeOutBack.transform(t / 0.5)
            : 1.15 - 0.15 * ((t - 0.5) / 0.5);
        final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
        return Positioned(
          left: widget.center.dx - chatGarraPulseSize / 2,
          top: widget.center.dy - chatGarraPulseSize / 2 - _rise * t,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: SizedBox.square(
        key: const Key('chat-garra-pulse'),
        dimension: chatGarraPulseSize,
        child: GarraClawReactionGlyph(
          size: chatGarraPulseSize,
          color: widget.color,
        ),
      ),
    );
  }
}
