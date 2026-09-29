import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/utils/garra_message_time.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../../chat/presentation/chat_unread_badge.dart';
import '../../chat/data/chat_models.dart';
import '../../clans/data/clan_models.dart';
import '../../clans/presentation/providers/clans_provider.dart';
import 'community_chat_page.dart';

/// COMMUNITY_GROUP_CHAT_14C: "Comunidades" segment of the Mensajes inbox.
/// Lists the viewer's ACTIVE communities from the existing `GET /clans/me`
/// provider ([myClansProvider]); no per-community chat request (no N+1), no
/// last-message preview and no per-community counters: the aggregated
/// community unread lives on the segment badge.
class CommunityChatInboxList extends ConsumerStatefulWidget {
  const CommunityChatInboxList({super.key});

  @override
  ConsumerState<CommunityChatInboxList> createState() =>
      _CommunityChatInboxListState();
}

class _CommunityChatInboxListState
    extends ConsumerState<CommunityChatInboxList> {
  Future<void> _refresh() async {
    ref.invalidate(chatUnreadCountProvider);
    ref.invalidate(communityChatPreviewsProvider);
    try {
      ref.invalidate(myClansProvider);
      await ref.read(myClansProvider.future);
    } catch (_) {
      // The error state (with retry) renders from the provider.
    }
  }

  Future<void> _open(ClanModel clan) async {
    await context.push(
      '/clans/${Uri.encodeComponent(clan.slug)}/chat',
      extra: CommunityChatSeed(name: clan.name, logoUrl: clan.logoUrl),
    );
    if (!mounted) return;
    // Back from the chat (read, left or lost access): refresh both.
    ref.invalidate(chatUnreadCountProvider);
    ref.invalidate(communityChatPreviewsProvider);
    ref.invalidate(myClansProvider);
  }

  @override
  Widget build(BuildContext context) {
    final memberships = ref.watch(myClansProvider);
    return memberships.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => GarraErrorState(
        title: 'No pudimos cargar tus comunidades',
        onRetry: () => ref.invalidate(myClansProvider),
      ),
      data: (items) {
        final clans = [
          for (final membership in items)
            if (membership.status.toUpperCase() == 'ACTIVE' &&
                membership.clan.slug.isNotEmpty)
              membership.clan,
        ];
        final previews = clans.isEmpty
            ? const <String, CommunityChatPreview>{}
            : ref.watch(communityChatPreviewsProvider).value ?? const <String, CommunityChatPreview>{};
        clans.sort((a, b) {
          final at = previews[a.slug]?.lastMessageAt;
          final bt = previews[b.slug]?.lastMessageAt;
          if (at == null) return bt == null ? 0 : 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        return RefreshIndicator(
          key: const Key('community-inbox-refresh'),
          onRefresh: _refresh,
          child: clans.isEmpty ? _empty() : _list(clans, previews),
        );
      },
    );
  }

  Widget _empty() {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: const GarraEmptyState(
              key: Key('community-inbox-empty'),
              title: 'A\u00fan no perteneces a ninguna comunidad.',
              message:
                  'Cuando te unas a una comunidad, su chat aparecer\u00e1 aqu\u00ed.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<ClanModel> clans, Map<String, CommunityChatPreview> previews) {
    final colors = context.garraColors;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: clans.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 76, color: colors.border),
      itemBuilder: (context, index) {
        final clan = clans[index];
        return _CommunityRow(clan: clan, preview: previews[clan.slug], onTap: () => _open(clan));
      },
    );
  }
}

class _CommunityRow extends StatelessWidget {
  const _CommunityRow({required this.clan, required this.preview, required this.onTap});

  final ClanModel clan;
  final CommunityChatPreview? preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final members = clan.memberCount;
    final subtitle = (preview?.lastMessagePreview.isNotEmpty ?? false)
        ? preview!.lastMessagePreview
        : members <= 0
        ? 'Chat de la comunidad'
        : (members == 1 ? '1 miembro' : '$members miembros');
    return Semantics(
      button: true,
      label: 'Abrir chat de ${clan.name}, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        key: Key('community-inbox-row-${clan.slug}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GarraSpacing.lg,
            vertical: 12,
          ),
          child: Row(
            children: [
              GarraAvatar(
                displayName: clan.name,
                avatarUrl: clan.logoUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                          fontWeight: (preview?.unreadCount ?? 0) > 0 ? FontWeight.w700 : FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      key: Key('community-inbox-members-${clan.slug}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (preview != null) Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (preview!.lastMessageAt != null)
                    Text(formatGarraMessageTime(preview!.lastMessageAt!),
                      style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  if (preview!.unreadCount > 0)
                    Badge(label: Text(preview!.unreadCount > 99 ? '99+' : '${preview!.unreadCount}')),
                ],
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
