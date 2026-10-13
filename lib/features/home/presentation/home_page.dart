import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config_service.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_brand_visual.dart';
import '../../../core/widgets/garra_states.dart';
import '../../chat/presentation/chat_unread_badge.dart';
import '../../football/data/garra_football_models.dart';
import 'home_feed_featured_block.dart';
import '../data/home_models.dart';
import 'providers/home_provider.dart';
import 'social_feed_tab.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeProvider);
    final featuredAsync = ref.watch(homeFeaturedProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.garraColors.background,
        shape: Border(bottom: BorderSide(color: context.garraColors.border)),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: GarraBrandLockup(compact: true, crestSize: 30),
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/comunidad/buscar'),
            icon: const Icon(Icons.search),
          ),
          // CHAT_V2_A: Mensajes entry with the shared unread badge.
          const GarraMessagesAction(),
          homeAsync.maybeWhen(
            data: (home) => _NotificationBell(
              unreadCount: home.notifications.unreadCount,
              onTap: () => context.push('/notifications'),
            ),
            orElse: () => IconButton(
              tooltip: 'Notificaciones',
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_none_outlined),
            ),
          ),
        ],
      ),
      body: homeAsync.when(
        loading: () => const GarraHomeSkeleton(),
        error: (error, stackTrace) =>
            GarraErrorState(onRetry: () => ref.invalidate(homeProvider)),
        data: (home) => _HomeBody(home: home, featured: featuredAsync),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
        child: const Icon(Icons.notifications_none_outlined),
      ),
    );
  }
}

enum _HomeFeedTab { forYou, following }

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody({required this.home, required this.featured});

  final HomeModel home;
  final AsyncValue<FootballFeaturedResult> featured;

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  _HomeFeedTab _tab = _HomeFeedTab.forYou;

  void _selectTab(_HomeFeedTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  /// PRODUCT-10A.2D: Marketplace is the existing `/marketplace` route, pushed
  /// on top of Home. The selected feed tab is not changed, so Back returns to
  /// the same feed (and scroll position) the fan left.
  void _openMarketplace() => context.push('/marketplace');

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    final forYouInserts = <Widget>[
      if (_hasContextualInsert(home))
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.lg,
            0,
            GarraSpacing.lg,
            GarraSpacing.md,
          ),
          child: _HomeContextualInsert(home: home),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.lg,
            GarraSpacing.sm,
            GarraSpacing.lg,
            GarraSpacing.xs,
          ),
          child: _FeedTabChips(
            tab: _tab,
            onChanged: _selectTab,
            // Same availability rule as the `/marketplace` route
            // (`_featureOrDisabled('marketplace')`): hidden when disabled.
            onMarketplace: appConfigService.current.feature('marketplace')
                ? _openMarketplace
                : null,
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _HomeFeedTab.forYou => SocialFeedTab(
              key: const ValueKey('FOR_YOU'),
              mode: 'FOR_YOU',
              header: HomeFeedFeaturedBlock(featured: widget.featured),
              contextualInserts: forYouInserts,
            ),
            _HomeFeedTab.following => SocialFeedTab(
              key: const ValueKey('FOLLOWING'),
              mode: 'FOLLOWING',
              header: HomeFeedFeaturedBlock(featured: widget.featured),
            ),
          },
        ),
      ],
    );
  }

  bool _hasContextualInsert(HomeModel home) {
    return home.clan != null ||
        home.community.posts.isNotEmpty ||
        home.commercial != null ||
        home.sponsored != null;
  }
}

class _HomeContextualInsert extends StatelessWidget {
  const _HomeContextualInsert({required this.home});

  final HomeModel home;

  @override
  Widget build(BuildContext context) {
    final clan = home.clan;
    final communityPost = home.community.posts.firstOrNull;
    final commercial = home.commercial;
    final sponsored = home.sponsored;

    String eyebrow;
    String title;
    String detail;
    IconData icon;
    VoidCallback? onTap;

    if (clan != null) {
      eyebrow = 'TU COMUNIDAD';
      title = clan.name;
      detail = '${clan.memberCount} miembros';
      icon = Icons.groups_outlined;
      onTap = () => context.push('/clans/${clan.slug}');
    } else if (communityPost != null) {
      eyebrow = 'EN LA TRIBUNA';
      title = communityPost.displayName;
      detail = communityPost.content;
      icon = Icons.forum_outlined;
      final postId = communityPost.id.trim();
      onTap = postId.isEmpty || postId == 'null'
          ? null
          : () => context.push('/muro-crema/posts/${Uri.encodeComponent(postId)}');
    } else {
      final card = commercial;
      eyebrow = card?.label ?? sponsored!.label;
      title = card?.headline ?? sponsored!.headline;
      detail = card?.body ?? sponsored!.body ?? '';
      icon = Icons.workspace_premium_outlined;
      onTap = () {
        final rewardSlug = card?.rewardSlug;
        if (rewardSlug != null && rewardSlug.isNotEmpty) {
          context.push('/rewards/$rewardSlug');
        }
      };
    }

    return Semantics(
      button: onTap != null,
      label: '$eyebrow, $title',
      child: Material(
        key: const ValueKey('home-contextual-insert'),
        color: context.garraColors.surface,
        borderRadius: BorderRadius.circular(GarraRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(GarraSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(
                      GarraColors.burgundy,
                    ).withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(GarraRadius.sm),
                  ),
                  child: Icon(icon, color: const Color(GarraColors.gold)),
                ),
                const SizedBox(width: GarraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(GarraColors.gold),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedTabChips extends StatelessWidget {
  const _FeedTabChips({
    required this.tab,
    required this.onChanged,
    this.onMarketplace,
  });

  final _HomeFeedTab tab;
  final ValueChanged<_HomeFeedTab> onChanged;

  /// Null when the `marketplace` feature flag is off: the tab is hidden.
  final VoidCallback? onMarketplace;

  @override
  Widget build(BuildContext context) {
    final items = <(String, bool, VoidCallback)>[
      ('Para ti', tab == _HomeFeedTab.forYou,
          () => onChanged(_HomeFeedTab.forYou)),
      ('Siguiendo', tab == _HomeFeedTab.following,
          () => onChanged(_HomeFeedTab.following)),
      if (onMarketplace != null) ('Marketplace', false, onMarketplace!),
    ];
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: GarraSpacing.sm),
          Expanded(
            child: Semantics(
              container: true,
              button: true,
              selected: items[index].$2,
              label: items[index].$1,
              excludeSemantics: true,
              child: Material(
                color: items[index].$2
                    ? context.garraColors.brandPrimary
                    : context.garraColors.surface,
                borderRadius: BorderRadius.circular(GarraRadius.pill),
                child: InkWell(
                  key: ValueKey('home_tab_${items[index].$1}'),
                  onTap: items[index].$3,
                  borderRadius: BorderRadius.circular(GarraRadius.pill),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5,
                            vertical: GarraSpacing.xs),
                        child: Text(
                          items[index].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: items[index].$2
                                ? context.garraColors.onBrand
                                : context.garraColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
