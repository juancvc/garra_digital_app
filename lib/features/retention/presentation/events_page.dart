import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/location/location_service.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/retention_models.dart';
import '../data/retention_service.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _service = RetentionService();
  List<GarraEventModel> _events = [];
  bool _loading = true;
  String? _error;
  String _filter = 'WEEK';

  static const _filters = [
    ('TODAY', 'Hoy'),
    ('WEEK', 'Esta semana'),
    ('NEAR', 'Cerca de mí'),
    ('COMMUNITY', 'Comunidades'),
    ('SOLIDARITY', 'Solidaria'),
  ];

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
      final apiFilter = _filter == 'NEAR' || _filter == 'COMMUNITY'
          ? 'WEEK'
          : _filter;
      var events = await _service.discoverEvents(filter: apiFilter);
      if (_filter == 'NEAR') {
        final gps = await AppLocationService().getCurrentLocation();
        if (gps.success && gps.latitude != null && gps.longitude != null) {
          events = events.where((e) => e.latitude != null && e.longitude != null).toList()
            ..sort((a, b) {
              final da = _approxDist(gps.latitude!, gps.longitude!, a.latitude!, a.longitude!);
              final db = _approxDist(gps.latitude!, gps.longitude!, b.latitude!, b.longitude!);
              return da.compareTo(db);
            });
        }
      }
      if (!mounted) return;
      setState(() {
        _events = events;
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

  double _approxDist(double lat1, double lon1, double lat2, double lon2) {
    final dLat = lat1 - lat2;
    final dLon = lon1 - lon2;
    return dLat * dLat + dLon * dLon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Eventos'),
        actions: [
          IconButton(
            tooltip: 'Proponer evento',
            onPressed: () => context.push('/eventos/nuevo'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.lg),
              children: _filters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: _filter == f.$1,
                        onSelected: (_) {
                          setState(() => _filter = f.$1);
                          _load();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? GarraErrorState(onRetry: _load)
                    : _events.isEmpty
                        ? const GarraEmptyState(
                            title: 'Sin eventos',
                            message:
                                'Pronto verás encuentros comunitarios verificados por Garra.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(GarraSpacing.lg),
                            itemCount: _events.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: GarraSpacing.md),
                            itemBuilder: (context, i) {
                              final e = _events[i];
                              return _EventCard(
                                event: e,
                                onTap: () => context.push('/eventos/${e.id}', extra: e),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});
  final GarraEventModel event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = event.startsAt == null
        ? ''
        : DateFormat('EEE d MMM · HH:mm', 'es')
            .format(DateTime.tryParse(event.startsAt!)?.toLocal() ??
                DateTime.now());
    return GarraCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(event.title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (event.verifiedByGarra)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(GarraColors.gold)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Verificado por Garra',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(GarraColors.gold),
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(date, style: Theme.of(context).textTheme.bodySmall),
          Text(event.zoneLabel, style: Theme.of(context).textTheme.labelSmall),
          if (event.myParticipation != null) ...[
            const SizedBox(height: 8),
            Text(
              event.myParticipation == 'GOING' ? 'Voy' : 'Me interesa',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(GarraColors.gold),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.eventId, this.initial});

  final String eventId;
  final GarraEventModel? initial;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _service = RetentionService();
  late GarraEventModel? _event = widget.initial;
  bool _busy = false;

  Future<void> _participate(bool going) async {
    setState(() => _busy = true);
    try {
      final updated = going
          ? await _service.markGoing(widget.eventId)
          : await _service.markInterested(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = updated;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar tu participación')),
      );
    }
  }

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    final gps = await AppLocationService().getCurrentLocation();
    if (!mounted) return;
    if (!gps.success) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(gps.message)),
      );
      return;
    }
    try {
      final updated = await _service.checkInEvent(
        widget.eventId,
        latitude: gps.latitude!,
        longitude: gps.longitude!,
      );
      if (!mounted) return;
      setState(() {
        _event = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.checkInLabel ?? 'Check-in registrado en el evento',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar el check-in')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: Text(e?.title ?? 'Evento')),
      body: e == null
          ? const Center(child: Text('Evento no disponible'))
          : ListView(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              children: [
                if (e.verifiedByGarra)
                  Text(
                    'Verificado por Garra',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(GarraColors.gold),
                        ),
                  ),
                const SizedBox(height: 8),
                Text(e.description ?? '',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: GarraSpacing.md),
                Text(e.zoneLabel),
                if (e.address != null) Text(e.address!),
                const SizedBox(height: GarraSpacing.xl),
                FilledButton(
                  onPressed: _busy ? null : () => _participate(false),
                  child: const Text('Me interesa'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : () => _participate(true),
                  child: const Text('Voy'),
                ),
                const SizedBox(height: 8),
                if (e.latitude != null && e.longitude != null)
                  OutlinedButton(
                    onPressed: _busy || e.checkedIn ? null : _checkIn,
                    child: Text(
                      e.checkedIn
                          ? (e.checkInLabel ??
                              'Check-in registrado en el evento')
                          : 'Registrar check-in',
                    ),
                  ),
                const SizedBox(height: GarraSpacing.lg),
                Text(
                  'Marcar «Voy» no confirma asistencia física. El check-in solo registra participación en la app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(GarraColors.creamMuted),
                      ),
                ),
              ],
            ),
    );
  }
}

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _service = RetentionService();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController(text: 'Lima');
  String _type = 'COMMUNITY_MEETUP';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.createEvent({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'type': _type,
        'city': _city.text.trim(),
        'startsAt': DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento enviado a revisión')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear el evento')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Proponer evento')),
      body: ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Ciudad'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            items: const [
              DropdownMenuItem(value: 'WATCH_PARTY', child: Text('Watch party')),
              DropdownMenuItem(
                  value: 'COMMUNITY_MEETUP', child: Text('Encuentro')),
              DropdownMenuItem(value: 'SOLIDARITY', child: Text('Solidaria')),
              DropdownMenuItem(value: 'BUSINESS', child: Text('Negocio')),
              DropdownMenuItem(value: 'CULTURAL', child: Text('Cultural')),
              DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
            decoration: const InputDecoration(labelText: 'Tipo'),
          ),
          const SizedBox(height: GarraSpacing.xl),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('Enviar a revisión'),
          ),
        ],
      ),
    );
  }
}
