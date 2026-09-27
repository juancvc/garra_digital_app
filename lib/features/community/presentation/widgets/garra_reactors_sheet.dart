import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_avatar.dart';
import '../../../../core/widgets/garra_sheet.dart';
import '../../data/reaction_type.dart';
import '../../data/reactor_model.dart';
import '../providers/community_provider.dart';
import 'garra_comment_reactions.dart';

/// "Who reacted" sheet for a post ([postId]) or a comment/reply ([commentId]).
/// Tapping a fan opens their public profile (`/comunidad/u/:id`).
Future<void> showGarraReactorsSheet(
  BuildContext context, {
  String? postId,
  String? commentId,
}) {
  assert((postId == null) != (commentId == null));
  final router = GoRouter.maybeOf(context);
  return showGarraSheet<void>(
    context: context,
    builder: (sheetContext) => GarraReactorsList(
      postId: postId,
      commentId: commentId,
      onOpenProfile: router == null
          ? null
          : (fanId) {
              Navigator.of(sheetContext).pop();
              router.push('/comunidad/u/$fanId');
            },
    ),
  );
}

class GarraReactorsList extends ConsumerStatefulWidget {
  const GarraReactorsList({
    super.key,
    this.postId,
    this.commentId,
    this.onOpenProfile,
  });

  final String? postId;
  final String? commentId;
  final ValueChanged<String>? onOpenProfile;

  @override
  ConsumerState<GarraReactorsList> createState() => _GarraReactorsListState();
}

class _GarraReactorsListState extends ConsumerState<GarraReactorsList> {
  final List<ReactorItem> _items = [];
  String? _nextCursor;
  bool _hasNext = false;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final service = ref.read(communityServiceProvider);
      final cursor = more ? _nextCursor : null;
      final page = widget.postId != null
          ? await service.getPostReactors(widget.postId!, cursor: cursor)
          : await service.getCommentReactors(widget.commentId!, cursor: cursor);
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(page.items);
        _hasNext = page.hasNext;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    Widget body;
    if (_items.isEmpty && _loading) {
      body = const Padding(
        padding: EdgeInsets.all(GarraSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_items.isEmpty && _error) {
      body = Padding(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudieron cargar las reacciones.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            TextButton(
              key: const ValueKey('reactors_retry'),
              onPressed: _load,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (_items.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        child: Text(
          'A\u00fan no hay reacciones.',
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
      );
    } else {
      body = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: GarraSpacing.md),
          children: [
            for (final item in _items)
              _ReactorTile(
                item: item,
                onTap: widget.onOpenProfile == null || item.fanId.isEmpty
                    ? null
                    : () => widget.onOpenProfile!(item.fanId),
              ),
            if (_hasNext)
              Center(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(GarraSpacing.sm),
                        child: CircularProgressIndicator(),
                      )
                    : TextButton(
                        key: const ValueKey('reactors_more'),
                        onPressed: () => _load(more: true),
                        child: const Text('Ver m\u00e1s'),
                      ),
              ),
          ],
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        key: const ValueKey('reactors_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.md,
              GarraSpacing.lg,
              GarraSpacing.sm,
            ),
            child: Text(
              'Reacciones',
              style: textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }
}

class _ReactorTile extends StatelessWidget {
  const _ReactorTile({required this.item, this.onTap});

  final ReactorItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final type = ReactionType.tryParse(item.type);
    return ListTile(
      key: ValueKey('reactor_${item.fanId}'),
      onTap: onTap,
      leading: GarraAvatar(
        displayName: item.displayName,
        avatarUrl: item.avatarUrl,
        size: 40,
      ),
      title: Text(
        item.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '@${item.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.textSecondary),
      ),
      trailing: type == null
          ? null
          : Semantics(
              label: type.labelEs,
              child: CommentReactionIcon(
                key: ValueKey('reactor_type_${item.fanId}_${type.apiValue}'),
                type: type,
                size: 22,
              ),
            ),
    );
  }
}