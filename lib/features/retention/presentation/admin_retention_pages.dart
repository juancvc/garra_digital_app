import 'package:flutter/material.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/retention_models.dart';
import '../data/retention_service.dart';

class AdminSeasonsPage extends StatefulWidget {
  const AdminSeasonsPage({super.key});

  @override
  State<AdminSeasonsPage> createState() => _AdminSeasonsPageState();
}

class _AdminSeasonsPageState extends State<AdminSeasonsPage> {
  final _service = RetentionService();
  List<SeasonModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.adminListSeasons();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final now = DateTime.now().toUtc();
    final created = await _service.adminCreateSeason(
      code: 'TEMP_${now.millisecondsSinceEpoch}',
      name: 'Temporada ${now.year}',
      description: 'Temporada Garra',
      startsAt: now.subtract(const Duration(days: 1)).toIso8601String(),
      endsAt: now.add(const Duration(days: 200)).toIso8601String(),
      themeKey: 'crema',
    );
    await _service.adminActivateSeason(created.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Temporadas'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = _items[i];
                return GarraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('${s.code} · ${s.status}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (s.status != 'ACTIVE')
                            TextButton(
                              onPressed: () async {
                                await _service.adminActivateSeason(s.id);
                                await _load();
                              },
                              child: const Text('Activar'),
                            ),
                          if (s.status == 'ACTIVE')
                            TextButton(
                              onPressed: () async {
                                await _service.adminCloseSeason(s.id);
                                await _load();
                              },
                              child: const Text('Cerrar'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class AdminAchievementsPage extends StatefulWidget {
  const AdminAchievementsPage({super.key});

  @override
  State<AdminAchievementsPage> createState() => _AdminAchievementsPageState();
}

class _AdminAchievementsPageState extends State<AdminAchievementsPage> {
  final _service = RetentionService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.adminListAchievements();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Logros')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final a = _items[i];
                final active = a['active'] != false;
                return GarraCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${a['name']}',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('${a['code']} · ${a['rarity']}'),
                          ],
                        ),
                      ),
                      Switch(
                        value: active,
                        onChanged: (v) async {
                          await _service.adminSetAchievementActive(
                              '${a['id']}', v);
                          await _load();
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

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  final _service = RetentionService();
  List<GarraEventModel> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.adminPendingEvents();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar eventos';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Eventos pendientes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? GarraErrorState(onRetry: _load)
              : _items.isEmpty
                  ? const GarraEmptyState(
                      title: 'Sin pendientes',
                      message: 'No hay eventos esperando verificación.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(GarraSpacing.lg),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: GarraSpacing.md),
                      itemBuilder: (context, i) {
                        final e = _items[i];
                        return GarraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(e.zoneLabel),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      await _service.adminVerifyEvent(e.id);
                                      await _load();
                                    },
                                    child: const Text('Verificar'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await _service.adminRejectEvent(e.id);
                                      await _load();
                                    },
                                    child: const Text('Rechazar'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await _service.adminCancelEvent(e.id);
                                      await _load();
                                    },
                                    child: const Text('Cancelar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
