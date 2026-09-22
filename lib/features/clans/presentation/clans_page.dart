import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
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
          IconButton(
            tooltip: 'Crear comunidad',
            onPressed: () => context.push('/clans/create'),
            icon: const Icon(Icons.add),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
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
                              loading: () =>
                                  ListView(children: const [GarraSkeleton(height: 100)]),
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
                              loading: () =>
                                  ListView(children: const [GarraSkeleton(height: 100)]),
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
                              loading: () =>
                                  ListView(children: const [GarraSkeleton(height: 100)]),
                              error: (_, _) => ListView(
                                children: [GarraErrorState(onRetry: _refresh)],
                              ),
                              data: (clans) {
                                final hasCity =
                                    city != null && city.trim().isNotEmpty;
                                if (!hasCity) {
                                  return ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(
                                      GarraSpacing.lg,
                                    ),
                                    children: [
                                      const GarraEmptyState(
                                        title: 'Comunidades cercanas',
                                        message:
                                            'Activa ubicación para ver comunidades cercanas',
                                      ),
                                      const SizedBox(height: GarraSpacing.lg),
                                      Text(
                                        'También puedes explorar comunidades públicas',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
  });

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
  const _InvitationsBanner({
    required this.pendingCount,
    required this.onTap,
  });

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
    final members =
        NumberFormat.decimalPattern('es').format(clan.memberCount);
    final member = isMember || clan.isMember;
    final cta = member
        ? 'Miembro'
        : ClanJoinPolicyLabels.label(clan.joinPolicy);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: GarraSpacing.xs),
      leading: GarraAvatar(
        displayName: clan.name,
        avatarUrl: clan.logoUrl,
        size: 44,
      ),
      title: Text(
        clan.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          ?roleLabel,
          '$members miembros',
          if (clan.locationLabel.isNotEmpty) clan.locationLabel,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onSetPrimary != null)
            IconButton(
              tooltip: 'Marcar principal',
              onPressed: onSetPrimary,
              icon: Icon(
                isPrimary ? Icons.star : Icons.star_border,
                color: isPrimary
                    ? const Color(GarraColors.gold)
                    : const Color(GarraColors.creamMuted),
              ),
            )
          else if (isPrimary)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Principal',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(GarraColors.gold),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          Text(
            cta,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: member
                      ? const Color(GarraColors.gold)
                      : const Color(GarraColors.cream),
                ),
          ),
        ],
      ),
      onTap: () => context.push('/clans/${clan.slug}'),
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
