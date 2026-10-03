import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/garra_spacing.dart';
import '../../../../core/network/connectivity_status.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_avatar.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../../../core/widgets/garra_official_badge.dart';
import '../../../../core/widgets/garra_states.dart';
import '../../../clans/data/clan_models.dart';
import '../../../clans/presentation/providers/clans_provider.dart';
import '../../../solidarity/data/solidarity_service.dart';
import '../../data/discovery_models.dart';
import '../../data/wall_post_model.dart';
import '../providers/community_provider.dart';

/// "Descubre en Garra": one bounded request (`GET /community/discovery`) with
/// people, communities, public posts and verified Solidaria initiatives.
///
/// * Loads once; rebuilds never refetch.
/// * Everything shown is already permission-filtered by the backend.
/// * Suggested content is visually separated from the followed feed and is
///   never auto-followed / auto-joined: every action is an explicit tap.
/// * A failure never breaks the host screen: it degrades to a small retry row.
/// * [compact] (onboarding) shows only people and communities.
class GarraDiscoverySection extends ConsumerStatefulWidget {
  const GarraDiscoverySection({
    super.key,
    this.compact = false,
    this.excludePostIds = const {},
    this.onFollowed,
  });

  final bool compact;

  /// Posts already shown in the host feed, to avoid duplicates.
  final Set<String> excludePostIds;

  /// Called after a successful follow (the host may refresh its feed).
  final VoidCallback? onFollowed;

  @override
  ConsumerState<GarraDiscoverySection> createState() =>
      _GarraDiscoverySectionState();
}

class _GarraDiscoverySectionState extends ConsumerState<GarraDiscoverySection>
    with AutomaticKeepAliveClientMixin {
  DiscoveryBundle? _bundle;
  bool _loading = true;
  bool _failed = false;
  final Set<String> _followed = {};
  final Set<String> _busy = {};
  final Map<String, String> _clanOutcome = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _bundle == null;
      _failed = false;
    });
    try {
      final bundle = await ref.read(communityServiceProvider).getDiscovery();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = _bundle == null;
        _loading = false;
      });
    }
  }

  bool get _offline =>
      ref.watch(connectivityStatusProvider) == NetworkConnectivity.offline;

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _follow(DiscoveryPerson person) async {
    final id = person.userId;
    if (_busy.contains(id) || _followed.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await ref.read(communityServiceProvider).followUser(id);
      if (!mounted) return;
      setState(() {
        _busy.remove(id);
        _followed.add(id);
      });
      widget.onFollowed?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      _toast('No pudimos seguir a este hincha. Int\u00e9ntalo de nuevo.');
    }
  }

  Future<void> _join(ClanModel clan) async {
    final slug = clan.slug;
    if (_busy.contains('clan:$slug') || _clanOutcome.containsKey(slug)) return;
    setState(() => _busy.add('clan:$slug'));
    try {
      final updated = await ref.read(clanServiceProvider).joinClan(slug);
      ref.invalidate(myClansProvider);
      if (!mounted) return;
      final requested =
          updated.hasPendingRequest ||
          (!updated.isMember && clan.joinPolicy == 'REQUEST');
      setState(() {
        _busy.remove('clan:$slug');
        _clanOutcome[slug] = requested ? 'REQUESTED' : 'JOINED';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy.remove('clan:$slug'));
      _toast('No pudimos completar la acci\u00f3n. Int\u00e9ntalo de nuevo.');
    }
  }

  /// Keep the loaded bundle while scrolled off-screen inside a lazy list, so
  /// scrolling never triggers a refetch.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.garraColors;
    final offline = _offline;
    if (_loading) {
      return const Padding(
        key: ValueKey('garra_discovery_loading'),
        padding: EdgeInsets.all(GarraSpacing.lg),
        child: GarraSkeleton(height: 150),
      );
    }
    if (_failed) {
      return Padding(
        key: const ValueKey('garra_discovery_error'),
        padding: const EdgeInsets.symmetric(
          horizontal: GarraSpacing.lg,
          vertical: GarraSpacing.sm,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'No pudimos cargar sugerencias.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            TextButton(
              onPressed: offline ? null : _load,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final bundle = _bundle;
    if (bundle == null) return const SizedBox.shrink();
    final posts = widget.compact
        ? const <WallPostModel>[]
        : bundle.posts
              .where((p) => !widget.excludePostIds.contains(p.id))
              .take(3)
              .toList();
    final solidarity = widget.compact
        ? const <DiscoverySolidarity>[]
        : bundle.solidarity;
    if (bundle.people.isEmpty &&
        bundle.communities.isEmpty &&
        posts.isEmpty &&
        solidarity.isEmpty) {
      return const SizedBox.shrink();
    }
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

    return Padding(
      key: const ValueKey('garra_discovery_section'),
      padding: const EdgeInsets.only(top: GarraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.explore_outlined,
                  size: 18,
                  color: colors.brandPrestige,
                ),
                const SizedBox(width: GarraSpacing.sm),
                Expanded(
                  child: Text(
                    'Descubre en Garra',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.xs,
              GarraSpacing.lg,
              GarraSpacing.sm,
            ),
            child: Text(
              'Sugerencias para ti. T\u00fa decides a qui\u00e9n seguir y qu\u00e9 comunidades unirte.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
          if (bundle.people.isNotEmpty) ...[
            const _RailLabel('Hinchas'),
            SizedBox(
              height: 214 * scale,
              child: ListView.separated(
                key: const ValueKey('garra_discovery_people'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.lg,
                ),
                itemCount: bundle.people.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: GarraSpacing.md),
                itemBuilder: (context, i) {
                  final person = bundle.people[i];
                  return _PersonCard(
                    person: person,
                    following: _followed.contains(person.userId),
                    busy: _busy.contains(person.userId),
                    offline: offline,
                    onFollow: () => _follow(person),
                    onOpen: () => context.push('/comunidad/u/${person.userId}'),
                  );
                },
              ),
            ),
          ],
          if (bundle.communities.isNotEmpty) ...[
            const _RailLabel('Comunidades'),
            SizedBox(
              height: 214 * scale,
              child: ListView.separated(
                key: const ValueKey('garra_discovery_communities'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.lg,
                ),
                itemCount: bundle.communities.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: GarraSpacing.md),
                itemBuilder: (context, i) {
                  final clan = bundle.communities[i];
                  return _CommunityCard(
                    clan: clan,
                    outcome: _clanOutcome[clan.slug],
                    busy: _busy.contains('clan:${clan.slug}'),
                    offline: offline,
                    onJoin: () => _join(clan),
                    onOpen: () => context.push('/clans/${clan.slug}'),
                  );
                },
              ),
            ),
          ],
          if (posts.isNotEmpty) ...[
            const _RailLabel('Publicaciones p\u00fablicas'),
            for (final post in posts)
              _PostTile(
                post: post,
                onOpen: () => context.push('/muro-crema/posts/${post.id}'),
              ),
          ],
          if (solidarity.isNotEmpty) ...[
            const _RailLabel('Garra Solidaria'),
            for (final item in solidarity)
              _SolidarityTile(
                item: item,
                onOpen: () => context.push('/solidaria/${item.id}'),
              ),
          ],
          const SizedBox(height: GarraSpacing.md),
        ],
      ),
    );
  }
}

class _RailLabel extends StatelessWidget {
  const _RailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.sm,
        GarraSpacing.lg,
        GarraSpacing.sm,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.garraColors.textSecondary,
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.following,
    required this.busy,
    required this.offline,
    required this.onFollow,
    required this.onOpen,
  });

  final DiscoveryPerson person;
  final bool following;
  final bool busy;
  final bool offline;
  final VoidCallback onFollow;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final official = isPlatformOfficialAccount(person.accountType);
    return SizedBox(
      width: 148,
      child: GarraCard(
        key: ValueKey('discovery_person_${person.userId}'),
        padding: const EdgeInsets.all(GarraSpacing.md),
        onTap: onOpen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                GarraAvatar(
                  displayName: person.displayName,
                  avatarUrl: person.avatarUrl,
                  size: 48,
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  person.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (official)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: GarraOfficialBadge(),
                  ),
                if (person.username.isNotEmpty)
                  Text(
                    '@${person.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: following
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('Siguiendo', maxLines: 1),
                    )
                  : FilledButton(
                      key: ValueKey('discovery_follow_${person.userId}'),
                      onPressed: busy || offline ? null : onFollow,
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Seguir', maxLines: 1),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.clan,
    required this.outcome,
    required this.busy,
    required this.offline,
    required this.onJoin,
    required this.onOpen,
  });

  final ClanModel clan;
  final String? outcome;
  final bool busy;
  final bool offline;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final request = clan.joinPolicy == 'REQUEST';
    final meta = [
      '${clan.memberCount} ${clan.memberCount == 1 ? 'miembro' : 'miembros'}',
      if ((clan.city ?? '').trim().isNotEmpty) clan.city!.trim(),
    ].join(' \u00b7 ');
    final String? doneLabel = switch (outcome) {
      'JOINED' => 'Ya eres parte',
      'REQUESTED' => 'Solicitud enviada',
      _ => null,
    };
    return SizedBox(
      width: 172,
      child: GarraCard(
        key: ValueKey('discovery_community_${clan.slug}'),
        padding: const EdgeInsets.all(GarraSpacing.md),
        onTap: onOpen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                GarraAvatar(
                  displayName: clan.name,
                  avatarUrl: clan.logoUrl,
                  size: 48,
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  clan.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: doneLabel != null
                  ? OutlinedButton(
                      onPressed: null,
                      child: Text(
                        doneLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : FilledButton(
                      key: ValueKey('discovery_join_${clan.slug}'),
                      onPressed: busy || offline ? null : onJoin,
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(request ? 'Solicitar' : 'Unirme', maxLines: 1),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact public post, deliberately lighter than the feed card so suggested
/// content is never confused with posts from people the user follows.
class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.onOpen});

  final WallPostModel post;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        0,
        GarraSpacing.lg,
        GarraSpacing.sm,
      ),
      child: GarraCard(
        key: ValueKey('discovery_post_${post.id}'),
        padding: const EdgeInsets.all(GarraSpacing.md),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GarraAvatar(
                  displayName: post.fullName,
                  avatarUrl: post.avatarUrl,
                  size: 28,
                ),
                const SizedBox(width: GarraSpacing.sm),
                Expanded(
                  child: Text(
                    post.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (post.isOfficial)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: GarraOfficialBadge(),
              ),
            const SizedBox(height: GarraSpacing.sm),
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: GarraSpacing.sm),
            Text(
              '${post.reactionCount} reacciones \u00b7 ${post.commentCount} comentarios',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Verified Solidaria initiative. Uses the community "success" tone and a
/// hands icon, intentionally different from the prestige-coloured shield of
/// "Garra Oficial": verified initiative != official account.
class _SolidarityTile extends StatelessWidget {
  const _SolidarityTile({required this.item, required this.onOpen});

  final DiscoverySolidarity item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final place = [
      if ((item.district ?? '').trim().isNotEmpty) item.district!.trim(),
      if ((item.city ?? '').trim().isNotEmpty) item.city!.trim(),
    ].join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        0,
        GarraSpacing.lg,
        GarraSpacing.sm,
      ),
      child: GarraCard(
        key: ValueKey('discovery_solidarity_${item.id}'),
        padding: const EdgeInsets.all(GarraSpacing.md),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.volunteer_activism_outlined,
                  size: 15,
                  color: colors.success,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Iniciativa verificada',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GarraSpacing.xs),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              [
                solidarityTypeLabel(item.type),
                if (place.isNotEmpty) place,
              ].join(' \u00b7 '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
