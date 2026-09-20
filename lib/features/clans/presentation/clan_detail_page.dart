import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/clan_models.dart';
import '../data/clan_service.dart';
import 'providers/clans_provider.dart';

class ClanDetailPage extends ConsumerStatefulWidget {
  const ClanDetailPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ClanDetailPage> createState() => _ClanDetailPageState();
}

class _ClanDetailPageState extends ConsumerState<ClanDetailPage> {
  bool _joining = false;
  bool _leaving = false;

  Future<void> _refresh() async {
    ref.invalidate(clanDetailProvider(widget.slug));
    ref.invalidate(clanMembersPreviewProvider(widget.slug));
    await ref.read(clanDetailProvider(widget.slug).future);
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await ref.read(clanServiceProvider).joinClan(widget.slug);
      ref.invalidate(clanDetailProvider(widget.slug));
      ref.invalidate(myClansProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listo')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos completar la acción. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _leave(ClanModel clan) async {
    if (clan.isOwner) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Transferir propiedad'),
          content: const Text(
            'Como propietario, primero debes transferir la propiedad '
            'a otro miembro antes de salir del clan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
            if (clan.canManage)
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/clans/${clan.slug}/manage');
                },
                child: const Text('Ir a gestión'),
              ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir del clan'),
        content: Text('¿Seguro que quieres salir de ${clan.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _leaving = true);
    try {
      await ref.read(clanServiceProvider).leaveClan(widget.slug);
      ref.invalidate(clanDetailProvider(widget.slug));
      ref.invalidate(myClansProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saliste del clan')),
        );
      }
    } on ClanServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos procesar tu salida. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clanAsync = ref.watch(clanDetailProvider(widget.slug));
    final membersAsync = ref.watch(clanMembersPreviewProvider(widget.slug));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: Text(clanAsync.asData?.value.name ?? 'Clan'),
        actions: [
          if (clanAsync.asData?.value.canManage == true)
            TextButton(
              onPressed: () =>
                  context.push('/clans/${widget.slug}/manage'),
              child: const Text('Gestionar'),
            ),
        ],
      ),
      body: clanAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (error, stackTrace) => GarraErrorState(onRetry: _refresh),
        data: (clan) => RefreshIndicator(
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
              _ClanHeader(clan: clan),
              const SizedBox(height: GarraSpacing.lg),
              if (clan.description != null &&
                  clan.description!.trim().isNotEmpty)
                GarraCard(
                  child: Text(
                    clan.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (clan.description != null &&
                  clan.description!.trim().isNotEmpty)
                const SizedBox(height: GarraSpacing.lg),
              _JoinSection(
                clan: clan,
                joining: _joining,
                leaving: _leaving,
                onJoin: _join,
                onLeave: () => _leave(clan),
              ),
              const SizedBox(height: GarraSpacing.xxl),
              membersAsync.when(
                loading: () => const GarraSkeleton(height: 80),
                error: (_, __) => const SizedBox.shrink(),
                data: (members) => _MembersPreview(members: members),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClanHeader extends StatelessWidget {
  const _ClanHeader({required this.clan});

  final ClanModel clan;

  @override
  Widget build(BuildContext context) {
    final members = NumberFormat.decimalPattern('es').format(clan.memberCount);
    return GarraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GarraAvatar(
            displayName: clan.name,
            avatarUrl: clan.logoUrl,
            size: 72,
          ),
          const SizedBox(width: GarraSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clan.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (clan.locationLabel.isNotEmpty) ...[
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    clan.locationLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  '$members miembros',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  ClanJoinPolicyLabels.indicator(clan.joinPolicy),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinSection extends StatelessWidget {
  const _JoinSection({
    required this.clan,
    required this.joining,
    required this.leaving,
    required this.onJoin,
    required this.onLeave,
  });

  final ClanModel clan;
  final bool joining;
  final bool leaving;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (clan.isSuspended) {
      return const GarraCard(
        child: Text(
          'Este clan está suspendido por ahora. No se pueden unir nuevos miembros.',
          style: TextStyle(color: Color(GarraColors.textSecondary)),
        ),
      );
    }

    if (clan.isMember) {
      return GarraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eres ${ClanRoleLabels.label(clan.myMembership?.role).toLowerCase()}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: GarraSpacing.md),
            GarraSecondaryButton(
              label: leaving ? 'Saliendo…' : 'Salir del clan',
              onPressed: leaving ? null : onLeave,
            ),
          ],
        ),
      );
    }

    if (clan.hasPendingRequest) {
      return GarraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solicitud pendiente',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: GarraSpacing.sm),
            Text(
              'Los administradores revisarán tu solicitud pronto.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final policy = clan.joinPolicy.toUpperCase();
    if (policy == 'INVITE_ONLY') {
      return const GarraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solo por invitación',
              style: TextStyle(
                color: Color(GarraColors.cream),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            SizedBox(height: GarraSpacing.sm),
            Text(
              'Este clan recibe nuevos miembros solo con invitación.',
              style: TextStyle(color: Color(GarraColors.textSecondary)),
            ),
          ],
        ),
      );
    }

    final label = ClanJoinPolicyLabels.label(clan.joinPolicy);
    return GarraCard(
      child: GarraPrimaryButton(
        label: label,
        loading: joining,
        onPressed: joining ? null : onJoin,
      ),
    );
  }
}

class _MembersPreview extends StatelessWidget {
  const _MembersPreview({required this.members});

  final List<ClanMemberModel> members;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GarraSectionHeader(
          title: 'Miembros',
          subtitle: 'Comunidad activa',
        ),
        const SizedBox(height: GarraSpacing.md),
        if (members.isEmpty)
          const GarraCard(
            child: Text(
              'Aún no hay miembros visibles.',
              style: TextStyle(color: Color(GarraColors.textSecondary)),
            ),
          )
        else
          ...members.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
              child: GarraCard(
                child: Row(
                  children: [
                    GarraAvatar(
                      displayName: m.displayName,
                      avatarUrl: m.avatarUrl,
                      size: 40,
                    ),
                    const SizedBox(width: GarraSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.displayName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '@${m.username}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      ClanRoleLabels.label(m.role),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(GarraColors.gold),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: const [
        GarraSkeleton(height: 100),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 80),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 56),
        SizedBox(height: GarraSpacing.xxl),
        GarraSkeleton(height: 120),
      ],
    );
  }
}
