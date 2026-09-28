import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/network/garra_error.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/clan_admin_permissions.dart';
import '../data/clan_models.dart';
import 'clan_moderation_dialogs.dart';
import 'providers/clans_provider.dart';

/// "Personas bloqueadas": active bans, OWNER/ADMIN only.
class ClanBansPage extends ConsumerWidget {
  const ClanBansPage({super.key, required this.slug});

  final String slug;

  Future<void> _unban(
    BuildContext context,
    WidgetRef ref,
    ClanBanModel ban,
  ) async {
    final name = ban.displayName.isNotEmpty
        ? ban.displayName
        : '@${ban.username}';
    final ok = await showClanConfirmDialog(
      context,
      title: '\u00bfQuitar el bloqueo a $name?',
      message:
          'Podr\u00e1 volver a unirse o solicitar ingreso. No recupera su membres\u00eda autom\u00e1ticamente.',
      confirmLabel: 'Quitar bloqueo',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(clanServiceProvider).unban(slug, ban.fanUserId);
      ref.invalidate(clanBansProvider(slug));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Quitaste el bloqueo a $name.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(garraActionErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.garraColors;
    final clanAsync = ref.watch(clanDetailProvider(slug));
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Personas bloqueadas')),
      body: clanAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.brandPrestige),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () => ref.invalidate(clanDetailProvider(slug)),
        ),
        data: (clan) {
          final actorRole = clan.isMember ? clan.myMembership!.role : null;
          if (!ClanAdminPermissions.canViewBans(actorRole)) {
            return const Padding(
              padding: EdgeInsets.all(GarraSpacing.xl),
              child: GarraEmptyState(
                title: 'Acceso restringido',
                message:
                    'Solo el propietario y los administradores ven los bloqueos.',
              ),
            );
          }
          final bansAsync = ref.watch(clanBansProvider(slug));
          return bansAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: colors.brandPrestige),
            ),
            error: (_, _) => GarraErrorState(
              onRetry: () => ref.invalidate(clanBansProvider(slug)),
            ),
            data: (bans) => RefreshIndicator(
              color: colors.brandPrestige,
              onRefresh: () async {
                ref.invalidate(clanBansProvider(slug));
                await ref.read(clanBansProvider(slug).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  GarraSpacing.lg,
                  GarraSpacing.md,
                  GarraSpacing.lg,
                  GarraSpacing.section,
                ),
                children: [
                  if (bans.isEmpty)
                    GarraCard(
                      child: Text(
                        'No hay personas bloqueadas.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  for (final ban in bans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                      child: _BanTile(
                        ban: ban,
                        canUnban: ClanAdminPermissions.canUnban(actorRole),
                        onUnban: () => _unban(context, ref, ban),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BanTile extends StatelessWidget {
  const _BanTile({
    required this.ban,
    required this.canUnban,
    required this.onUnban,
  });

  final ClanBanModel ban;
  final bool canUnban;
  final VoidCallback onUnban;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final textTheme = Theme.of(context).textTheme;
    final name = ban.displayName.isNotEmpty ? ban.displayName : ban.username;
    final date = clanShortDate(ban.createdAt);
    final by = ban.bannedByDisplayName;
    final meta = [
      if (date.isNotEmpty) 'Bloqueado el $date',
      if (by != null && by.isNotEmpty) 'por $by',
    ].join(' ');
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GarraAvatar(
                displayName: name,
                avatarUrl: ban.avatarUrl,
                size: 40,
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (ban.username.isNotEmpty)
                      Text(
                        '@${ban.username}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              meta,
              style: textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (ban.reason != null) ...[
            const SizedBox(height: GarraSpacing.xs),
            Text(
              'Motivo: ${ban.reason}',
              style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
          ],
          if (canUnban)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey('unban_${ban.fanUserId}'),
                onPressed: onUnban,
                style: TextButton.styleFrom(
                  foregroundColor: colors.brandPrestige,
                ),
                child: const Text('Quitar bloqueo'),
              ),
            ),
        ],
      ),
    );
  }
}
