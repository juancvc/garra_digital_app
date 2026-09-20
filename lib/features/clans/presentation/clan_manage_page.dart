import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/clan_models.dart';
import 'providers/clans_provider.dart';

class ClanManagePage extends ConsumerStatefulWidget {
  const ClanManagePage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ClanManagePage> createState() => _ClanManagePageState();
}

class _ClanManagePageState extends ConsumerState<ClanManagePage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  String _visibility = 'PUBLIC';
  String _joinPolicy = 'OPEN';
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _hydrate(ClanModel clan) {
    if (_initialized) return;
    _nameController.text = clan.name;
    _descriptionController.text = clan.description ?? '';
    _cityController.text = clan.city ?? '';
    _countryController.text = clan.countryCode ?? '';
    _visibility = clan.visibility;
    _joinPolicy = clan.joinPolicy;
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(clanServiceProvider).updateClan(
            widget.slug,
            UpdateClanRequest(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              city: _cityController.text.trim(),
              countryCode: _countryController.text.trim().toUpperCase(),
              visibility: _visibility,
              joinPolicy: _joinPolicy,
            ),
          );
      ref.invalidate(clanDetailProvider(widget.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clan actualizado')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos guardar los cambios. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(clanDetailProvider(widget.slug));
    ref.invalidate(clanJoinRequestsProvider(widget.slug));
    ref.invalidate(clanMembersPreviewProvider(widget.slug));
    await Future.wait([
      ref.read(clanDetailProvider(widget.slug).future),
      ref.read(clanJoinRequestsProvider(widget.slug).future),
      ref.read(clanMembersPreviewProvider(widget.slug).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final clanAsync = ref.watch(clanDetailProvider(widget.slug));
    final requestsAsync = ref.watch(clanJoinRequestsProvider(widget.slug));
    final membersAsync = ref.watch(clanMembersPreviewProvider(widget.slug));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Gestionar clan')),
      body: clanAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, __) => GarraErrorState(onRetry: _refresh),
        data: (clan) {
          _hydrate(clan);
          return RefreshIndicator(
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
                const GarraSectionHeader(
                  title: 'Perfil del clan',
                  subtitle: 'Nombre, descripción y acceso',
                ),
                const SizedBox(height: GarraSpacing.md),
                GarraCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                        ),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      TextField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'País (código)',
                        ),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      DropdownButtonFormField<String>(
                        value: _visibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibilidad',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PUBLIC',
                            child: Text('Público'),
                          ),
                          DropdownMenuItem(
                            value: 'MEMBERS_ONLY',
                            child: Text('Solo miembros'),
                          ),
                          DropdownMenuItem(
                            value: 'PRIVATE',
                            child: Text('Privado'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _visibility = v);
                        },
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      DropdownButtonFormField<String>(
                        value: _joinPolicy,
                        decoration: const InputDecoration(
                          labelText: 'Política de ingreso',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'OPEN',
                            child: Text('Abierto'),
                          ),
                          DropdownMenuItem(
                            value: 'REQUEST',
                            child: Text('Con solicitud'),
                          ),
                          DropdownMenuItem(
                            value: 'INVITE_ONLY',
                            child: Text('Solo invitación'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _joinPolicy = v);
                        },
                      ),
                      const SizedBox(height: GarraSpacing.lg),
                      GarraPrimaryButton(
                        label: 'Guardar',
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GarraSpacing.xxl),
                const GarraSectionHeader(
                  title: 'Solicitudes pendientes',
                  subtitle: 'Aprueba o rechaza ingresos',
                ),
                const SizedBox(height: GarraSpacing.md),
                requestsAsync.when(
                  loading: () => const GarraSkeleton(height: 80),
                  error: (_, __) => GarraErrorState(onRetry: _refresh),
                  data: (requests) {
                    final pending = requests
                        .where((r) => r.status.toUpperCase() == 'PENDING')
                        .toList();
                    if (pending.isEmpty) {
                      return const GarraCard(
                        child: Text(
                          'No hay solicitudes pendientes.',
                          style: TextStyle(
                            color: Color(GarraColors.textSecondary),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: pending
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: GarraSpacing.sm,
                              ),
                              child: _RequestCard(
                                request: r,
                                onApprove: () async {
                                  await ref
                                      .read(clanServiceProvider)
                                      .approveJoinRequest(widget.slug, r.id);
                                  ref.invalidate(
                                    clanJoinRequestsProvider(widget.slug),
                                  );
                                  ref.invalidate(
                                    clanDetailProvider(widget.slug),
                                  );
                                  ref.invalidate(
                                    clanMembersPreviewProvider(widget.slug),
                                  );
                                },
                                onReject: () async {
                                  await ref
                                      .read(clanServiceProvider)
                                      .rejectJoinRequest(widget.slug, r.id);
                                  ref.invalidate(
                                    clanJoinRequestsProvider(widget.slug),
                                  );
                                },
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: GarraSpacing.xxl),
                const GarraSectionHeader(
                  title: 'Miembros',
                  subtitle: 'Comunidad del clan',
                ),
                const SizedBox(height: GarraSpacing.md),
                membersAsync.when(
                  loading: () => const GarraSkeleton(height: 80),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (members) {
                    if (members.isEmpty) {
                      return const GarraCard(
                        child: Text(
                          'Sin miembros para mostrar.',
                          style: TextStyle(
                            color: Color(GarraColors.textSecondary),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: members
                          .map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: GarraSpacing.sm,
                              ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.displayName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          Text(
                                            '@${m.username}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      ClanRoleLabels.label(m.role),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color:
                                                const Color(GarraColors.gold),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final ClanJoinRequestModel request;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GarraAvatar(
                displayName: request.displayName,
                avatarUrl: request.avatarUrl,
                size: 40,
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '@${request.username}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message != null &&
              request.message!.trim().isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              request.message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: GarraSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onReject(),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => onApprove(),
                  child: const Text('Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
