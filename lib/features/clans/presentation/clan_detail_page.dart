import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/network/garra_error.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/utils/country_labels.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../../community/presentation/providers/community_provider.dart';
import '../data/clan_models.dart';
import '../data/clan_service.dart';
import 'clan_tribuna_page.dart';
import 'providers/clans_provider.dart';

String clanMembersFailureTitle(Object error) => 'No pudimos cargar los miembros.';

String clanMembersFailureMessage(Object error) {
  if (classifyDioError(error).kind == GarraErrorKind.offline) {
    return 'Revisa tu conexión e inténtalo de nuevo.';
  }
  return 'Inténtalo de nuevo.';
}

class ClanDetailPage extends ConsumerStatefulWidget {
  const ClanDetailPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ClanDetailPage> createState() => _ClanDetailPageState();
}

class _ClanDetailPageState extends ConsumerState<ClanDetailPage>
    with SingleTickerProviderStateMixin {
  bool _joining = false;
  bool _leaving = false;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(clanDetailProvider(widget.slug));
    ref.invalidate(clanMembersPreviewProvider(widget.slug));
    ref.invalidate(clanFeedProvider(widget.slug));
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
            'a otro miembro antes de salir de la comunidad.',
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
        title: const Text('Salir de la comunidad'),
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
          const SnackBar(content: Text('Saliste de la comunidad')),
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

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: Text(clanAsync.asData?.value.name ?? 'Comunidad'),
        actions: [
          if (clanAsync.asData?.value.canManage == true) ...[
            IconButton(
              tooltip: 'Invitar',
              onPressed: () => _showInviteDialog(context, widget.slug),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
            TextButton(
              onPressed: () => context.push('/clans/${widget.slug}/manage'),
              child: const Text('Administrar'),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Publicaciones'),
            Tab(text: 'Miembros'),
            Tab(text: 'Información'),
          ],
        ),
      ),
      body: clanAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (error, stackTrace) => GarraErrorState(onRetry: _refresh),
        data: (clan) => Column(
          children: [
            _GroupHeader(
              clan: clan,
              joining: _joining,
              leaving: _leaving,
              onJoin: _join,
              onLeave: () => _leave(clan),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  ClanTribunaPage(
                    slug: widget.slug,
                    clanName: clan.name,
                    embedded: true,
                  ),
                  _CommunityMembersTab(slug: widget.slug),
                  _CommunityInfoTab(clan: clan),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, String slug) async {
    final usernameCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(GarraColors.surface),
        title: const Text('Invitar a una comunidad'),
        content: TextField(
          controller: usernameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'usuario_crema',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar invitación'),
          ),
        ],
      ),
    );
    final username = usernameCtrl.text.trim();
    usernameCtrl.dispose();
    if (sent != true || username.isEmpty) return;
    try {
      await ref.read(clanServiceProvider).inviteMember(slug, username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación enviada')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos enviar la invitación. Revisa el username.'),
        ),
      );
    }
  }
}


class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
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
    final members = NumberFormat.decimalPattern('es').format(clan.memberCount);
    return SizedBox(
      height: 176,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 92,
            child: clan.bannerUrl != null && clan.bannerUrl!.isNotEmpty
                ? Image.network(
                    clan.bannerUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    errorBuilder: (_, _, _) => const _CoverFallback(),
                  )
                : const _CoverFallback(),
          ),
          Positioned(
            left: 16,
            top: 58,
            child: GarraAvatar(
              displayName: clan.name,
              avatarUrl: clan.logoUrl,
              size: 64,
            ),
          ),
          Positioned(
            left: 92,
            right: 12,
            top: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$members miembros · ${clanVisibilityLabel(clan.visibility)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      if (clan.isMember)
                        OutlinedButton(
                          onPressed: leaving ? null : onLeave,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(72, 36),
                          ),
                          child: Text(leaving ? 'Saliendo…' : 'Unido ✓'),
                        )
                      else if (clan.hasPendingRequest)
                        const Text('Solicitud pendiente')
                      else if (clan.joinPolicy.toUpperCase() == 'INVITE_ONLY' ||
                          clan.isSuspended)
                        Text(
                          clan.isSuspended
                              ? 'Suspendida'
                              : 'Solo por invitación',
                        )
                      else
                        FilledButton(
                          onPressed: joining ? null : onJoin,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(72, 36),
                          ),
                          child: Text(
                            joining
                                ? 'Uniendo…'
                                : ClanJoinPolicyLabels.label(clan.joinPolicy),
                          ),
                        ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        SharePlus.instance.share(
                          ShareParams(text: '${clan.name} en Garra Digital'),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(72, 36),
                      ),
                      child: const Text('Compartir'),
                    ),
                  ],
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

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(GarraColors.garnetDeep), Color(GarraColors.charcoal)],
        ),
      ),
    );
  }
}

class _CommunityInfoTab extends StatelessWidget {
  const _CommunityInfoTab({required this.clan});

  final ClanModel clan;

  @override
  Widget build(BuildContext context) {
    final country = countryName(clan.countryCode);
    final created = clan.createdAt == null
        ? null
        : DateFormat('d/M/y').format(clan.createdAt!.toLocal());
    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: [
        if ((clan.description ?? '').trim().isNotEmpty)
          Text(clan.description!),
        const SizedBox(height: GarraSpacing.md),
        _InfoLine(label: 'Ciudad', value: (clan.city ?? '').trim().isEmpty ? '—' : clan.city!),
        _InfoLine(label: 'País', value: country.isEmpty ? '—' : country),
        _InfoLine(label: 'Privacidad', value: clanVisibilityLabel(clan.visibility)),
        _InfoLine(
          label: 'Miembros',
          value: NumberFormat.decimalPattern('es').format(clan.memberCount),
        ),
        _InfoLine(
          label: 'Ingreso',
          value: ClanJoinPolicyLabels.indicator(clan.joinPolicy),
        ),
        if (created != null) _InfoLine(label: 'Creada', value: created),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CommunityMembersTab extends ConsumerStatefulWidget {
  const _CommunityMembersTab({required this.slug});

  final String slug;

  @override
  ConsumerState<_CommunityMembersTab> createState() =>
      _CommunityMembersTabState();
}

class _CommunityMembersTabState extends ConsumerState<_CommunityMembersTab> {
  final List<ClanMemberModel> _items = [];
  final Set<String> _following = {};
  String? _cursor;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref.read(clanServiceProvider).getMembers(
            widget.slug,
            cursor: reset ? null : _cursor,
          );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _cursor = page.nextCursor;
        _hasNext = page.hasNext;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error;
      });
    }
  }

  Future<void> _toggleFollow(ClanMemberModel member) async {
    final id = member.fanUserId;
    if (id == null || id.isEmpty) return;
    final service = ref.read(communityServiceProvider);
    final following = _following.contains(id);
    setState(() {
      if (following) {
        _following.remove(id);
      } else {
        _following.add(id);
      }
    });
    try {
      if (following) {
        await service.unfollowUser(id);
      } else {
        await service.followUser(id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (following) {
          _following.add(id);
        } else {
          _following.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos actualizar el seguimiento.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(GarraColors.gold)),
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        children: [
          GarraErrorState(
            title: clanMembersFailureTitle(_error!),
            message: clanMembersFailureMessage(_error!),
            onRetry: () => _load(reset: true),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return GarraEmptyState(
        title: 'Aún no hay miembros',
        message: 'Cuando alguien se una, aparecerá aquí.',
        actionLabel: 'Reintentar',
        onAction: () => _load(reset: true),
      );
    }
    return RefreshIndicator(
      color: const Color(GarraColors.gold),
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_hasNext ? 1 : 0),
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Color(GarraColors.borderSubtle)),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return TextButton(
              onPressed: _loadingMore ? null : () => _load(reset: false),
              child: Text(_loadingMore ? 'Cargando…' : 'Cargar más'),
            );
          }
          final member = _items[index];
          final id = member.fanUserId;
          final following = id != null && _following.contains(id);
          return ListTile(
            leading: GarraAvatar(
              displayName: member.displayName,
              avatarUrl: member.avatarUrl,
              size: 40,
            ),
            title: Text(member.displayName),
            subtitle: Text(
              member.username.isEmpty ? '' : '@${member.username}',
            ),
            onTap: id == null || id.isEmpty
                ? null
                : () => context.push('/comunidad/u/$id'),
            trailing: id == null || id.isEmpty
                ? null
                : TextButton(
                    onPressed: () => _toggleFollow(member),
                    child: Text(following ? 'Siguiendo' : 'Seguir'),
                  ),
          );
        },
      ),
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
