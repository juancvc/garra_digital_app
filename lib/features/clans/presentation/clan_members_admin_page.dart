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

/// "Miembros" admin subpage: roles, expulsar, expulsar y bloquear and
/// ownership transfer, offered per the actor role (backend stays authority).
class ClanMembersAdminPage extends ConsumerStatefulWidget {
  const ClanMembersAdminPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ClanMembersAdminPage> createState() =>
      _ClanMembersAdminPageState();
}

class _ClanMembersAdminPageState extends ConsumerState<ClanMembersAdminPage> {
  final List<ClanMemberModel> _members = [];
  String? _cursor;
  bool _hasNext = false;
  bool _loading = true;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final page = await ref
          .read(clanServiceProvider)
          .getMembers(widget.slug, cursor: reset ? null : _cursor, size: 50);
      if (!mounted) return;
      setState(() {
        if (reset) _members.clear();
        _members.addAll(page.items);
        _cursor = page.nextCursor;
        _hasNext = page.hasNext;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _nameOf(ClanMemberModel m) =>
      m.displayName.isNotEmpty ? m.displayName : '@${m.username}';

  Future<void> _run(ClanMemberAction action, ClanMemberModel member) async {
    final service = ref.read(clanServiceProvider);
    final name = _nameOf(member);
    String? done;
    setState(() => _busy = true);
    try {
      switch (action) {
        case ClanMemberAction.makeAdmin:
        case ClanMemberAction.makeModerator:
        case ClanMemberAction.makeMember:
          final role = ClanAdminPermissions.roleFor(action)!;
          await service.updateMemberRole(widget.slug, member.username, role);
          done = '$name ahora es ${ClanRoleLabels.label(role).toLowerCase()}.';
        case ClanMemberAction.remove:
          final ok = await showClanConfirmDialog(
            context,
            title: '\u00bfExpulsar a $name?',
            message: 'Podr\u00e1 volver a unirse.',
            confirmLabel: 'Expulsar',
          );
          if (!ok) break;
          await service.removeMember(widget.slug, member.username);
          done = 'Expulsaste a $name.';
        case ClanMemberAction.ban:
          final choice = await showClanBanDialog(context, name: name);
          if (choice == null) break;
          await service.banMember(
            widget.slug,
            member.username,
            reason: choice.reason,
          );
          done = '$name fue expulsado y bloqueado.';
        case ClanMemberAction.transferOwnership:
          final ok = await showClanConfirmDialog(
            context,
            title: '\u00bfTransferir la propiedad a $name?',
            message:
                '$name ser\u00e1 el nuevo propietario y t\u00fa pasar\u00e1s a ser administrador.',
            confirmLabel: 'Transferir',
          );
          if (!ok) break;
          await service.transferOwnership(widget.slug, member.username);
          done = 'Transferiste la propiedad a $name.';
      }
    } catch (e) {
      if (mounted) _snack(garraActionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (done == null || !mounted) return;
    _snack(done);
    ref.invalidate(clanDetailProvider(widget.slug));
    ref.invalidate(clanMembersPreviewProvider(widget.slug));
    ref.invalidate(clanBansProvider(widget.slug));
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final clanAsync = ref.watch(clanDetailProvider(widget.slug));
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Miembros')),
      body: clanAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.brandPrestige),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () => ref.invalidate(clanDetailProvider(widget.slug)),
        ),
        data: (clan) {
          final actorRole = clan.isMember ? clan.myMembership!.role : null;
          if (!ClanAdminPermissions.canManageCommunity(actorRole)) {
            return const Padding(
              padding: EdgeInsets.all(GarraSpacing.xl),
              child: GarraEmptyState(
                title: 'Acceso restringido',
                message:
                    'Solo el propietario y los administradores gestionan miembros.',
              ),
            );
          }
          return _buildList(context, actorRole);
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, String? actorRole) {
    final colors = context.garraColors;
    if (_loading && _members.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: colors.brandPrestige),
      );
    }
    if (_error != null && _members.isEmpty) {
      return GarraErrorState(onRetry: () => _load(reset: true));
    }
    return RefreshIndicator(
      color: colors.brandPrestige,
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.section,
        ),
        children: [
          if (_members.isEmpty)
            GarraCard(
              child: Text(
                'Sin miembros para mostrar.',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          for (final member in _members)
            Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
              child: _MemberAdminTile(
                member: member,
                actions: ClanAdminPermissions.actionsFor(
                  actor: actorRole,
                  target: member.role,
                ),
                enabled: !_busy,
                onAction: (action) => _run(action, member),
              ),
            ),
          if (_hasNext)
            TextButton(
              onPressed: _loading ? null : () => _load(),
              child: Text(_loading ? 'Cargando...' : 'Cargar m\u00e1s'),
            ),
        ],
      ),
    );
  }
}

class _MemberAdminTile extends StatelessWidget {
  const _MemberAdminTile({
    required this.member,
    required this.actions,
    required this.enabled,
    required this.onAction,
  });

  final ClanMemberModel member;
  final List<ClanMemberAction> actions;
  final bool enabled;
  final ValueChanged<ClanMemberAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final textTheme = Theme.of(context).textTheme;
    final name = member.displayName.isNotEmpty
        ? member.displayName
        : member.username;
    final since = clanShortDate(member.joinedAt);
    return GarraCard(
      child: Row(
        children: [
          GarraAvatar(displayName: name, avatarUrl: member.avatarUrl, size: 40),
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
                Text(
                  '@${member.username}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  since.isEmpty ? 'Activo' : 'Activo \u00b7 desde $since',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            ClanRoleLabels.label(member.role),
            key: ValueKey('member_role_${member.username}'),
            style: textTheme.labelMedium?.copyWith(
              color: colors.brandPrestige,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actions.isNotEmpty)
            PopupMenuButton<ClanMemberAction>(
              key: ValueKey('member_actions_${member.username}'),
              enabled: enabled,
              tooltip: 'Acciones',
              icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
              color: colors.surfaceRaised,
              onSelected: onAction,
              itemBuilder: (_) => [
                for (final action in actions)
                  PopupMenuItem(
                    value: action,
                    child: Text(
                      ClanAdminPermissions.label(action),
                      style: TextStyle(
                        color:
                            action == ClanMemberAction.remove ||
                                action == ClanMemberAction.ban
                            ? colors.danger
                            : colors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
