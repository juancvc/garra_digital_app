import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/clan_models.dart';
import 'providers/clans_provider.dart';
import 'widgets/garra_clan_card.dart';

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
      appBar: AppBar(
        title: const Text('Clanes'),
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
      ),
      body: hasError
          ? GarraErrorState(onRetry: _refresh)
          : isLoading && !myClansAsync.hasValue && !discoveryAsync.hasValue
              ? const _ClansSkeleton()
              : RefreshIndicator(
                  color: const Color(GarraColors.gold),
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      GarraSpacing.lg,
                      GarraSpacing.md,
                      GarraSpacing.lg,
                      GarraSpacing.section,
                    ),
                    children: [
                      _SearchField(
                        controller: _searchController,
                        onSubmitted: (value) {
                          setState(() => _search = value.trim());
                        },
                      ),
                      const SizedBox(height: GarraSpacing.lg),
                      _InvitationsEntry(pendingCount: invitationCount),
                      const SizedBox(height: GarraSpacing.xxl),
                      myClansAsync.when(
                        loading: () => const GarraSkeleton(height: 100),
                        error: (_, __) => GarraErrorState(onRetry: _refresh),
                        data: (memberships) => _MyClansSection(
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
                        loading: () => const GarraSkeleton(height: 140),
                        error: (_, __) => GarraErrorState(onRetry: _refresh),
                        data: (clans) => _ExploreSection(clans: clans),
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
        hintText: 'Buscar clanes…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Buscar',
          onPressed: () => onSubmitted(controller.text),
          icon: const Icon(Icons.arrow_forward),
        ),
      ),
    );
  }
}

class _InvitationsEntry extends StatelessWidget {
  const _InvitationsEntry({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      onTap: () => context.push('/clans/invitations'),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, color: Color(GarraColors.gold)),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invitaciones',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  pendingCount > 0
                      ? 'Tienes $pendingCount pendiente${pendingCount == 1 ? '' : 's'}'
                      : 'Revisa invitaciones a comunidades crema',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
        ],
      ),
    );
  }
}

class _MyClansSection extends StatelessWidget {
  const _MyClansSection({
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
        const GarraSectionHeader(
          title: 'Mis Clanes',
          subtitle: 'Tus comunidades activas',
        ),
        const SizedBox(height: GarraSpacing.md),
        if (memberships.isEmpty)
          const GarraEmptyState(
            title: 'Aún no tienes clan',
            message:
                'Explora comunidades crema y encuentra el lugar donde te sientas en casa.',
          )
        else
          ...memberships.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.md),
              child: GarraClanCard(
                clan: m.clan,
                isPrimary: m.isPrimary,
                showJoinPolicy: false,
                roleLabel: ClanRoleLabels.label(m.role),
                onTap: () => context.push('/clans/${m.clan.slug}'),
                trailing: m.isPrimary
                    ? null
                    : TextButton(
                        onPressed: () => onSetPrimary(m.clan.slug),
                        child: const Text('Principal'),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExploreSection extends StatelessWidget {
  const _ExploreSection({required this.clans});

  final List<ClanModel> clans;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GarraSectionHeader(
          title: 'Explorar',
          subtitle: 'Comunidades abiertas a la hinchada',
        ),
        const SizedBox(height: GarraSpacing.md),
        if (clans.isEmpty)
          const GarraEmptyState(
            title: 'Sin clanes por ahora',
            message:
                'Cuando se creen comunidades, aparecerán aquí para que puedas unirte.',
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

class _ClansSkeleton extends StatelessWidget {
  const _ClansSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: const [
        GarraSkeleton(height: 52),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 72),
        SizedBox(height: GarraSpacing.xxl),
        GarraSkeleton(height: 120),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 120),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 120),
      ],
    );
  }
}
