import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/solidarity_service.dart';
import 'solidaria_shared.dart';

/// "Mis iniciativas": the owner's campaigns in every state, so nothing looks
/// frozen after submitting (borrador / en revisi\u00f3n / publicada / no aprobada
/// with Garra's reason). Backed by `GET /solidarity/campaigns/me`.
class SolidariaMinePage extends StatefulWidget {
  const SolidariaMinePage({super.key, this.service});

  final SolidarityService? service;

  @override
  State<SolidariaMinePage> createState() => _SolidariaMinePageState();
}

class _SolidariaMinePageState extends State<SolidariaMinePage> {
  late final SolidarityService _service =
      widget.service ?? SolidarityService();
  List<SolidarityCampaign> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      if (!refresh) _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listMine();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _open(SolidarityCampaign c) async {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    await router.push('/solidaria/${c.id}');
    if (mounted) _load(refresh: true);
  }

  Future<void> _propose() async {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final ok = await router.push<bool>('/solidaria/nueva');
    if (ok == true && mounted) _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis iniciativas'),
        actions: [
          IconButton(
            tooltip: '\u00bfC\u00f3mo funciona?',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showSolidariaHowItWorks(context),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          GarraErrorState(
            title: 'No pudimos cargar tus iniciativas',
            onRetry: _load,
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: _items.isEmpty
          ? ListView(
              children: [
                GarraEmptyState(
                  title: 'A\u00fan no propusiste iniciativas',
                  message:
                      'Cuando propongas una, aqu\u00ed ver\u00e1s si est\u00e1 en revisi\u00f3n, '
                      'publicada o si necesitas corregirla.',
                  actionLabel: 'Proponer iniciativa',
                  onAction: _propose,
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.sm,
                GarraSpacing.lg,
                GarraSpacing.xl,
              ),
              itemCount: _items.length,
              itemBuilder: (_, i) => _MineCard(
                campaign: _items[i],
                onTap: () => _open(_items[i]),
              ),
            ),
    );
  }
}

class _MineCard extends StatelessWidget {
  const _MineCard({required this.campaign, required this.onTap});

  final SolidarityCampaign campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final text = Theme.of(context).textTheme;
    final c = campaign;
    final reason = c.ownerState == SolidarityOwnerState.rejected
        ? c.rejectionReason
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: GarraCard(
        key: ValueKey('solidarity_mine_${c.id}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SolidarityStateChip(c),
            const SizedBox(height: 6),
            Text(c.title, style: text.titleMedium),
            const SizedBox(height: 2),
            Text(
              solidarityTypeLabel(c.type),
              style: text.bodySmall?.copyWith(color: colors.brandPrestige),
            ),
            const SizedBox(height: 6),
            Text(
              solidarityStateDescription(c.ownerState),
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            if (reason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Motivo: $reason',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: colors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
