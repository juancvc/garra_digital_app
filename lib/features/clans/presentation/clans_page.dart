import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_brand_visual.dart';
import '../../../core/widgets/garra_cached_network_image.dart';
import '../../../core/widgets/garra_states.dart';
import '../../passport/presentation/providers/passport_provider.dart';
import '../data/clan_models.dart';
import 'providers/clans_provider.dart';

/// Product surface: Comunidades Cremas (backend domain remains clans).
class ClansPage extends ConsumerStatefulWidget {
  const ClansPage({super.key});

  @override
  ConsumerState<ClansPage> createState() => _ClansPageState();
}

class _ClansPageState extends ConsumerState<ClansPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _search = '';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  ClanDiscoveryQuery get _discoveryQuery => ClanDiscoveryQuery(search: _search);

  ClanDiscoveryQuery _nearbyQuery(String? city) => ClanDiscoveryQuery(
    search: _search,
    city: city?.trim().isNotEmpty == true ? city!.trim() : null,
  );

  Future<void> _refresh() async {
    final city = ref.read(myPassportProvider).asData?.value.identity.city;
    ref.invalidate(myClansProvider);
    ref.invalidate(clanDiscoveryProvider(_discoveryQuery));
    ref.invalidate(clanDiscoveryProvider(_nearbyQuery(city)));
    ref.invalidate(myClanInvitationsProvider);
    await Future.wait([
      ref.read(myClansProvider.future),
      ref.read(clanDiscoveryProvider(_discoveryQuery).future),
      ref.read(myClanInvitationsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final myClansAsync = ref.watch(myClansProvider);
    final discoveryAsync = ref.watch(clanDiscoveryProvider(_discoveryQuery));
    final invitationsAsync = ref.watch(myClanInvitationsProvider);
    final passportAsync = ref.watch(myPassportProvider);
    final city = passportAsync.asData?.value.identity.city;
    final nearbyAsync = ref.watch(clanDiscoveryProvider(_nearbyQuery(city)));

    final invitationCount = invitationsAsync.maybeWhen(
      data: (list) => list.where((i) => i.isPending).length,
      orElse: () => 0,
    );

    final isLoading = myClansAsync.isLoading || discoveryAsync.isLoading;
    final hasError = myClansAsync.hasError && discoveryAsync.hasError;

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Comunidades'),
        actions: [
          IconButton(
            tooltip: 'Invitaciones',
            onPressed: () => context.push('/clans/invitations'),
            icon: Badge(
              isLabelVisible: invitationCount > 0,
              label: Text('$invitationCount'),
              child: const Icon(Icons.mail_outline),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(GarraColors.gold),
          labelColor: const Color(GarraColors.cream),
          unselectedLabelColor: const Color(GarraColors.creamMuted),
          tabs: const [
            Tab(text: 'Mis comunidades'),
            Tab(text: 'Descubrir'),
            Tab(text: 'Cercanas'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clans/create'),
        backgroundColor: const Color(GarraColors.garnet),
        foregroundColor: const Color(GarraColors.cream),
        child: const Icon(Icons.add),
      ),
      body: hasError
          ? GarraErrorState(onRetry: _refresh)
          : isLoading && !myClansAsync.hasValue && !discoveryAsync.hasValue
          ? const _CommunitiesSkeleton()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GarraSpacing.lg,
                    GarraSpacing.md,
                    GarraSpacing.lg,
                    0,
                  ),
                  child: const _CommunitiesHero(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GarraSpacing.lg,
                    GarraSpacing.md,
                    GarraSpacing.lg,
                    0,
                  ),
                  child: _SearchField(
                    controller: _searchController,
                    onSubmitted: (value) {
                      setState(() => _search = value.trim());
                    },
                  ),
                ),
                if (invitationCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GarraSpacing.lg,
                      GarraSpacing.md,
                      GarraSpacing.lg,
                      0,
                    ),
                    child: _InvitationsBanner(
                      pendingCount: invitationCount,
                      onTap: () => context.push('/clans/invitations'),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        color: const Color(GarraColors.gold),
                        onRefresh: _refresh,
                        child: myClansAsync.when(
                          loading: () => ListView(
                            children: const [GarraSkeleton(height: 100)],
                          ),
                          error: (_, _) => ListView(
                            children: [GarraErrorState(onRetry: _refresh)],
                          ),
                          data: (memberships) => _MyCommunitiesTab(
                            memberships: memberships,
                            onSetPrimary: (slug) async {
                              await ref
                                  .read(clanServiceProvider)
                                  .setPrimaryClan(slug);
                              ref.invalidate(myClansProvider);
                            },
                          ),
                        ),
                      ),
                      RefreshIndicator(
                        color: const Color(GarraColors.gold),
                        onRefresh: _refresh,
                        child: discoveryAsync.when(
                          loading: () => ListView(
                            children: const [GarraSkeleton(height: 100)],
                          ),
                          error: (_, _) => ListView(
                            children: [GarraErrorState(onRetry: _refresh)],
                          ),
                          data: (clans) => _DiscoverTab(
                            clans: clans,
                            emptyTitle: 'Sin resultados',
                            emptyMessage:
                                'Prueba otro término o crea una comunidad nueva.',
                          ),
                        ),
                      ),
                      RefreshIndicator(
                        color: const Color(GarraColors.gold),
                        onRefresh: _refresh,
                        child: nearbyAsync.when(
                          loading: () => ListView(
                            children: const [GarraSkeleton(height: 100)],
                          ),
                          error: (_, _) => ListView(
                            children: [GarraErrorState(onRetry: _refresh)],
                          ),
                          data: (clans) {
                            final hasCity =
                                city != null && city.trim().isNotEmpty;
                            if (!hasCity) {
                              return ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(GarraSpacing.lg),
                                children: [
                                  const GarraEmptyState(
                                    title: 'Comunidades cercanas',
                                    message:
                                        'Activa ubicación para ver comunidades cercanas',
                                  ),
                                  const SizedBox(height: GarraSpacing.lg),
                                  Text(
                                    'También puedes explorar comunidades públicas',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: GarraSpacing.md),
                                  ...clans.map(
                                    (clan) => _ClanListTile(clan: clan),
                                  ),
                                ],
                              );
                            }
                            return _DiscoverTab(
                              clans: clans,
                              emptyTitle: 'Nada cerca aún',
                              emptyMessage:
                                  'No encontramos comunidades en $city. Explora en Descubrir.',
                              subtitle: 'Cercanas · $city',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CommunitiesHero extends StatelessWidget {
  const _CommunitiesHero();

  @override
  Widget build(BuildContext context) {
    return GarraAtmosphericHero(
      height: 116,
      alignment: const Alignment(0, -0.35),
      padding: const EdgeInsets.all(GarraSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const GarraCrest(size: 42, showGlow: true),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GarraEditorialEyebrow(
                  label: 'Tribuna crema',
                  icon: Icons.groups_outlined,
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  'Tu gente. Tu barrio. Tu crema.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(GarraColors.cream),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Buscar comunidades',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: const Color(GarraColors.surface),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarraRadius.md),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: 'Buscar',
          onPressed: () => onSubmitted(controller.text),
          icon: const Icon(Icons.arrow_forward),
        ),
      ),
    );
  }
}

class _InvitationsBanner extends StatelessWidget {
  const _InvitationsBanner({required this.pendingCount, required this.onTap});

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(GarraColors.garnetDeep),
      borderRadius: BorderRadius.circular(GarraRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GarraRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.mail, color: Color(GarraColors.gold)),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Text(
                  pendingCount == 1
                      ? 'Tienes 1 invitación pendiente'
                      : 'Tienes $pendingCount invitaciones pendientes',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(GarraColors.cream),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyCommunitiesTab extends StatelessWidget {
  const _MyCommunitiesTab({
    required this.memberships,
    required this.onSetPrimary,
  });

  final List<MyClanMembership> memberships;
  final Future<void> Function(String slug) onSetPrimary;

  @override
  Widget build(BuildContext context) {
    if (memberships.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: const [
          GarraEmptyState(
            title: 'Aún no tienes comunidad',
            message:
                'Únete a una comunidad crema o crea la tuya para compartir la tribuna.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        88,
      ),
      itemCount: memberships.length,
      separatorBuilder: (_, _) => const SizedBox(height: GarraSpacing.sm),
      itemBuilder: (context, index) {
        final m = memberships[index];
        return _ClanListTile(
          clan: m.clan,
          roleLabel: ClanRoleLabels.label(m.role),
          isMember: true,
          isPrimary: m.isPrimary,
          onSetPrimary: m.isPrimary ? null : () => onSetPrimary(m.clan.slug),
        );
      },
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab({
    required this.clans,
    required this.emptyTitle,
    required this.emptyMessage,
    this.subtitle,
  });

  final List<ClanModel> clans;
  final String emptyTitle;
  final String emptyMessage;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        88,
      ),
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(GarraColors.creamMuted),
            ),
          ),
          const SizedBox(height: GarraSpacing.md),
        ],
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/clans/ranking'),
              child: const Text('Ranking'),
            ),
          ],
        ),
        if (clans.isEmpty)
          GarraEmptyState(title: emptyTitle, message: emptyMessage)
        else
          ...clans.map((clan) => _ClanListTile(clan: clan)),
      ],
    );
  }
}

class _ClanListTile extends StatelessWidget {
  const _ClanListTile({
    required this.clan,
    this.roleLabel,
    this.isMember = false,
    this.isPrimary = false,
    this.onSetPrimary,
  });

  final ClanModel clan;
  final String? roleLabel;
  final bool isMember;
  final bool isPrimary;
  final VoidCallback? onSetPrimary;

  @override
  Widget build(BuildContext context) {
    final members = NumberFormat.decimalPattern('es').format(clan.memberCount);
    final member = isMember || clan.isMember;
    final cta = member
        ? 'Miembro'
        : ClanJoinPolicyLabels.label(clan.joinPolicy);

    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
      child: Material(
        color: const Color(GarraColors.surface),
        borderRadius: BorderRadius.circular(GarraRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/clans/${clan.slug}'),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 76,
                color: isPrimary
                    ? const Color(GarraColors.gold)
                    : const Color(GarraColors.burgundy),
              ),
              _ClanVisual(
                name: clan.name,
                logoUrl: clan.logoUrl,
                bannerUrl: clan.bannerUrl,
              ),
              const SizedBox(width: GarraSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        ?roleLabel,
                        '$members miembros',
                        if (clan.locationLabel.isNotEmpty) clan.locationLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onSetPrimary != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _MembershipLabel(label: 'Miembro'),
                    IconButton(
                      tooltip: 'Marcar principal',
                      visualDensity: VisualDensity.compact,
                      onPressed: onSetPrimary,
                      icon: Icon(
                        isPrimary ? Icons.star : Icons.star_border,
                        color: isPrimary
                            ? const Color(GarraColors.gold)
                            : const Color(GarraColors.creamMuted),
                      ),
                    ),
                  ],
                )
              else if (member)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GarraSpacing.sm,
                  ),
                  child: _MembershipLabel(
                    label: isPrimary ? 'Principal' : 'Miembro',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GarraSpacing.sm,
                  ),
                  child: _JoinLabel(label: cta),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClanVisual extends StatelessWidget {
  const _ClanVisual({
    required this.name,
    required this.logoUrl,
    required this.bannerUrl,
  });

  final String name;
  final String? logoUrl;
  final String? bannerUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: bannerUrl != null && bannerUrl!.isNotEmpty
                ? GarraCachedNetworkImage(
                    imageUrl: bannerUrl!,
                    fit: BoxFit.cover,
                    errorWidget: const _ClanBannerFallback(),
                  )
                : const _ClanBannerFallback(),
          ),
          Container(
            color: const Color(GarraColors.charcoal).withValues(alpha: 0.3),
          ),
          GarraAvatar(displayName: name, avatarUrl: logoUrl, size: 44),
        ],
      ),
    );
  }
}

class _ClanBannerFallback extends StatelessWidget {
  const _ClanBannerFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(GarraColors.burgundyDeep),
            Color(GarraColors.surfaceRaised),
          ],
        ),
      ),
    );
  }
}

class _MembershipLabel extends StatelessWidget {
  const _MembershipLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label == 'Principal' ? 'Comunidad principal' : 'Ya eres miembro',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 18,
            color: Color(GarraColors.success),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(GarraColors.creamMuted),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinLabel extends StatelessWidget {
  const _JoinLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(GarraColors.gold)),
        borderRadius: BorderRadius.circular(GarraRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(GarraColors.gold),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CommunitiesSkeleton extends StatelessWidget {
  const _CommunitiesSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(GarraSpacing.lg),
      child: Column(
        children: [
          GarraSkeleton(height: 56),
          SizedBox(height: GarraSpacing.lg),
          GarraSkeleton(height: 100),
          SizedBox(height: GarraSpacing.md),
          GarraSkeleton(height: 100),
        ],
      ),
    );
  }
}
