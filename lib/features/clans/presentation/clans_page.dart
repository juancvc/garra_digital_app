import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/clan_models.dart';
import 'providers/clans_provider.dart';
import 'widgets/garra_clan_card.dart';

/// Product surface: Comunidades Cremas (backend domain remains clans).
class ClansPage extends ConsumerStatefulWidget {
  const ClansPage({super.key});

  @override
  ConsumerState<ClansPage> createState() => _ClansPageState();
}

class _ClansPageState extends ConsumerState<ClansPage> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ClanDiscoveryQuery get _query => ClanDiscoveryQuery(search: _search);

  Future<void> _refresh() async {
    ref.invalidate(myClansProvider);
    ref.invalidate(clanDiscoveryProvider(_query));
    ref.invalidate(myClanInvitationsProvider);
    await Future.wait([
      ref.read(myClansProvider.future),
      ref.read(clanDiscoveryProvider(_query).future),
      ref.read(myClanInvitationsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final myClansAsync = ref.watch(myClansProvider);
    final discoveryAsync = ref.watch(clanDiscoveryProvider(_query));
    final invitationsAsync = ref.watch(myClanInvitationsProvider);

    final invitationCount = invitationsAsync.maybeWhen(
      data: (list) => list.where((i) => i.isPending).length,
      orElse: () => 0,
    );

    final isLoading = myClansAsync.isLoading || discoveryAsync.isLoading;
    final hasError = myClansAsync.hasError && discoveryAsync.hasError;

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clans/create'),
        backgroundColor: const Color(GarraColors.garnet),
        foregroundColor: const Color(GarraColors.cream),
        icon: const Icon(Icons.add),
        label: const Text('Crear comunidad'),
      ),
      body: hasError
          ? GarraErrorState(onRetry: _refresh)
          : isLoading && !myClansAsync.hasValue && !discoveryAsync.hasValue
              ? const _CommunitiesSkeleton()
              : RefreshIndicator(
                  color: const Color(GarraColors.gold),
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _HeroHeader(
                        invitationCount: invitationCount,
                        onInvitations: () => context.push('/clans/invitations'),
                      )),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          GarraSpacing.lg,
                          0,
                          GarraSpacing.lg,
                          GarraSpacing.section,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _SearchField(
                              controller: _searchController,
                              onSubmitted: (value) {
                                setState(() => _search = value.trim());
                              },
                            ),
                            if (invitationCount > 0) ...[
                              const SizedBox(height: GarraSpacing.lg),
                              _InvitationsBanner(
                                pendingCount: invitationCount,
                                onTap: () =>
                                    context.push('/clans/invitations'),
                              ),
                            ],
                            const SizedBox(height: GarraSpacing.xxl),
                            myClansAsync.when(
                              loading: () =>
                                  const GarraSkeleton(height: 100),
                              error: (_, __) =>
                                  GarraErrorState(onRetry: _refresh),
                              data: (memberships) => _MyCommunitiesSection(
                                memberships: memberships,
                                onSetPrimary: (slug) async {
                                  await ref
                                      .read(clanServiceProvider)
                                      .setPrimaryClan(slug);
                                  ref.invalidate(myClansProvider);
                                },
                              ),
                            ),
                            const SizedBox(height: GarraSpacing.xxl),
                            discoveryAsync.when(
                              loading: () =>
                                  const GarraSkeleton(height: 140),
                              error: (_, __) =>
                                  GarraErrorState(onRetry: _refresh),
                              data: (clans) =>
                                  _DiscoverSection(clans: clans),
                            ),
                            const SizedBox(height: 88),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.invitationCount,
    required this.onInvitations,
  });

  final int invitationCount;
  final VoidCallback onInvitations;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.xxl,
        GarraSpacing.lg,
        GarraSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(GarraColors.garnetDeep),
            Color(GarraColors.charcoal),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Comunidades Cremas',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(GarraColors.cream),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Invitaciones',
                  onPressed: onInvitations,
                  icon: Badge(
                    isLabelVisible: invitationCount > 0,
                    label: Text('$invitationCount'),
                    child: const Icon(
                      Icons.mail_outline,
                      color: Color(GarraColors.cream),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GarraSpacing.sm),
            Text(
              'Encuentra tu gente. De tu barrio, ciudad o desde cualquier parte.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(GarraColors.creamMuted),
                  ),
            ),
          ],
        ),
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

class _MyCommunitiesSection extends StatelessWidget {
  const _MyCommunitiesSection({
    required this.memberships,
    required this.onSetPrimary,
  });

  final List<MyClanMembership> memberships;
  final Future<void> Function(String slug) onSetPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis comunidades',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(GarraColors.cream),
              ),
        ),
        const SizedBox(height: GarraSpacing.md),
        if (memberships.isEmpty)
          const GarraEmptyState(
            title: 'Aún no tienes comunidad',
            message:
                'Únete a una comunidad crema o crea la tuya para compartir la tribuna.',
          )
        else
          ...memberships.take(5).map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: GarraSpacing.md),
                  child: GarraClanCard(
                    clan: m.clan,
                    roleLabel: ClanRoleLabels.label(m.role),
                    isPrimary: m.isPrimary,
                    showJoinPolicy: false,
                    onTap: () => context.push('/clans/${m.clan.slug}'),
                    trailing: m.isPrimary
                        ? const Icon(Icons.star, color: Color(GarraColors.gold))
                        : IconButton(
                            tooltip: 'Marcar principal',
                            onPressed: () => onSetPrimary(m.clan.slug),
                            icon: const Icon(
                              Icons.star_border,
                              color: Color(GarraColors.creamMuted),
                            ),
                          ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _DiscoverSection extends StatelessWidget {
  const _DiscoverSection({required this.clans});

  final List<ClanModel> clans;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Descubre',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(GarraColors.cream),
                    ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/clans/ranking'),
              child: const Text('Ranking'),
            ),
          ],
        ),
        const SizedBox(height: GarraSpacing.xs),
        Text(
          'Comunidades públicas cerca de la hinchada',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: GarraSpacing.md),
        if (clans.isEmpty)
          const GarraEmptyState(
            title: 'Sin resultados',
            message: 'Prueba otro término o crea una comunidad nueva.',
          )
        else
          ...clans.map(
            (clan) => Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.md),
              child: GarraClanCard(
                clan: clan,
                onTap: () => context.push('/clans/${clan.slug}'),
              ),
            ),
          ),
      ],
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
          GarraSkeleton(height: 120),
          SizedBox(height: GarraSpacing.lg),
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
