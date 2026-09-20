import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/clan_models.dart';
import 'providers/clans_provider.dart';
import 'widgets/garra_clan_card.dart';

class ClanInvitationsPage extends ConsumerWidget {
  const ClanInvitationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(myClanInvitationsProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Invitaciones')),
      body: invitationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, __) => GarraErrorState(
          onRetry: () => ref.invalidate(myClanInvitationsProvider),
        ),
        data: (invitations) {
          final pending =
              invitations.where((i) => i.isPending).toList(growable: false);
          if (pending.isEmpty) {
            return const GarraEmptyState(
              title: 'Sin invitaciones',
              message:
                  'Cuando te inviten a un clan, aparecerán aquí para aceptar o rechazar.',
            );
          }

          return RefreshIndicator(
            color: const Color(GarraColors.gold),
            onRefresh: () async {
              ref.invalidate(myClanInvitationsProvider);
              await ref.read(myClanInvitationsProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.section,
              ),
              itemCount: pending.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: GarraSpacing.md),
              itemBuilder: (context, index) {
                final invitation = pending[index];
                return _InvitationCard(
                  invitation: invitation,
                  onAccept: () async {
                    await ref
                        .read(clanServiceProvider)
                        .acceptInvitation(invitation.id);
                    ref.invalidate(myClanInvitationsProvider);
                    ref.invalidate(myClansProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Te uniste a ${invitation.clan.name}'),
                        ),
                      );
                    }
                  },
                  onDecline: () async {
                    await ref
                        .read(clanServiceProvider)
                        .declineInvitation(invitation.id);
                    ref.invalidate(myClanInvitationsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invitación rechazada')),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  final ClanInvitationModel invitation;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  Widget build(BuildContext context) {
    final invitedBy = invitation.invitedByDisplayName ??
        invitation.invitedByUsername;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GarraClanCard(
          clan: invitation.clan,
          showJoinPolicy: false,
          onTap: () => context.push('/clans/${invitation.clan.slug}'),
        ),
        if (invitedBy != null && invitedBy.isNotEmpty) ...[
          const SizedBox(height: GarraSpacing.sm),
          Text(
            'Invitado por $invitedBy',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: GarraSpacing.md),
        Row(
          children: [
            Expanded(
              child: GarraSecondaryButton(
                label: 'Rechazar',
                onPressed: () => onDecline(),
              ),
            ),
            const SizedBox(width: GarraSpacing.md),
            Expanded(
              child: GarraPrimaryButton(
                label: 'Aceptar',
                onPressed: () => onAccept(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
