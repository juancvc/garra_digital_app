import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/checkin_model.dart';
import '../data/crema_point_model.dart';
import '../data/create_checkin_request.dart';
import 'providers/location_provider.dart';
import '../../../core/location/location_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../retention/data/retention_models.dart';
import '../../retention/data/retention_service.dart';

class RutaAlTemploPage extends ConsumerStatefulWidget {
  const RutaAlTemploPage({super.key});

  @override
  ConsumerState<RutaAlTemploPage> createState() => _RutaAlTemploPageState();
}

class _RutaAlTemploPageState extends ConsumerState<RutaAlTemploPage> {
  String _selectedType = 'ALL';

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(cremaPointsProvider);
    final checkInsAsync = ref.watch(myCheckInsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ruta al Templo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.gold,
          backgroundColor: context.garraColors.surface,
          onRefresh: () async {
            ref.invalidate(cremaPointsProvider);
            ref.invalidate(myCheckInsProvider);

            await Future.wait([
              ref.read(cremaPointsProvider.future),
              ref.read(myCheckInsProvider.future),
            ]);
          },
          child: pointsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.gold),
            ),
            error: (_, _) => GarraErrorState(
              title: 'No pudimos cargar los puntos crema',
              onRetry: () {
                ref.invalidate(cremaPointsProvider);
                ref.invalidate(myCheckInsProvider);
              },
            ),
            data: (points) {
              return checkInsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.gold),
                ),
                error: (_, _) => GarraErrorState(
                  title: 'No pudimos cargar tus check-ins',
                  onRetry: () {
                    ref.invalidate(cremaPointsProvider);
                    ref.invalidate(myCheckInsProvider);
                  },
                ),
                data: (checkIns) {
                  final filteredPoints = _selectedType == 'ALL'
                      ? points
                      : points
                            .where((point) => point.type == _selectedType)
                            .toList();

                  if (points.isEmpty) {
                    return const _EmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredPoints.length + 3,

                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const _Header();
                      }

                      if (index == 1) {
                        return SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.push('/mapa-crema'),
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('Ver mapa'),
                          ),
                        );
                      }

                      if (index == 2) {
                        return _TypeFilters(
                          selectedType: _selectedType,
                          onChanged: (type) {
                            setState(() => _selectedType = type);
                          },
                        );
                      }

                      final point = filteredPoints[index - 3];
                      final checkIn = _findCheckInForPoint(
                        checkIns: checkIns,
                        cremaPointId: point.id,
                      );

                      return _CremaPointCard(point: point, checkIn: checkIn);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  CheckInModel? _findCheckInForPoint({
    required List<CheckInModel> checkIns,
    required String cremaPointId,
  }) {
    for (final checkIn in checkIns) {
      if (checkIn.cremaPointId == cremaPointId) {
        return checkIn;
      }
    }

    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.burgundy, Color(0xFF2A0B0F)],
        ),
        border: Border.all(color: AppTheme.cream.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route_rounded, color: AppTheme.gold, size: 32),
          const SizedBox(height: 14),
          const Text(
            'Ruta al Templo',
            style: TextStyle(
              color: AppTheme.cream,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Encuentra puntos crema y registra tu check-in.',
            style: TextStyle(
              color: AppTheme.cream.withValues(alpha: 0.72),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeFilters extends StatelessWidget {
  const _TypeFilters({required this.selectedType, required this.onChanged});

  final String selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = [
      _PointTypeFilter(label: 'Todos', value: 'ALL'),
      _PointTypeFilter(label: 'Estadio', value: 'STADIUM'),
      _PointTypeFilter(label: 'Negocio', value: 'BUSINESS'),
      _PointTypeFilter(label: 'Punto de encuentro', value: 'MEETING_POINT'),
      _PointTypeFilter(label: 'Banderazo', value: 'BANDERAZO'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = selectedType == filter.value;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: selected,
              selectedColor: context.garraColors.brandPrimary,
              backgroundColor: context.garraColors.surfaceRaised,
              labelStyle: TextStyle(
                color: selected
                    ? context.garraColors.onBrand
                    : context.garraColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(
                color: selected
                    ? context.garraColors.brandPrimary
                    : context.garraColors.border,
              ),
              onSelected: (_) => onChanged(filter.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PointTypeFilter {
  const _PointTypeFilter({required this.label, required this.value});

  final String label;
  final String value;
}

class _CremaPointCard extends ConsumerStatefulWidget {
  const _CremaPointCard({required this.point, required this.checkIn});

  final CremaPointModel point;
  final CheckInModel? checkIn;

  @override
  ConsumerState<_CremaPointCard> createState() => _CremaPointCardState();
}

class _CremaPointCardState extends ConsumerState<_CremaPointCard> {
  bool _submitting = false;
  double? _distanceMeters;
  bool _loadingDistance = false;

  String _normalizeCheckInMessage(String message) {
    if (message.contains('Valid check-in already exists')) {
      return 'Ya tienes un check-in válido en este punto durante las últimas 12 horas';
    }

    if (message.contains('Check-in processed successfully')) {
      return 'Check-in procesado correctamente';
    }

    if (message.contains('too far') || message.contains('outside')) {
      return 'Estás fuera del rango permitido para este punto';
    }

    return message;
  }

  Future<void> _loadDistance() async {
    setState(() => _loadingDistance = true);

    final gpsResult = await AppLocationService().getCurrentLocation();

    if (!mounted) return;

    if (!gpsResult.success) {
      setState(() => _loadingDistance = false);
      return;
    }

    final distance = Geolocator.distanceBetween(
      gpsResult.latitude!,
      gpsResult.longitude!,
      widget.point.latitude,
      widget.point.longitude,
    );

    setState(() {
      _distanceMeters = distance;
      _loadingDistance = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDistance();
  }

  Future<void> _createCheckIn() async {
    setState(() => _submitting = true);

    final gpsResult = await AppLocationService().getCurrentLocation();

    if (!mounted) return;

    if (!gpsResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gpsResult.message),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() => _submitting = false);
      return;
    }

    final service = ref.read(locationServiceProvider);

    final result = await service.createCheckIn(
      CreateCheckInRequest(
        cremaPointId: widget.point.id,
        latitude: gpsResult.latitude!,
        longitude: gpsResult.longitude!,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_normalizeCheckInMessage(result.message)),
        backgroundColor: result.success ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );

    ref.invalidate(myCheckInsProvider);
    ref.invalidate(cremaPointsProvider);

    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final checkIn = widget.checkIn;
    final hasCheckIn = checkIn != null;
    final canCheckIn = _distanceMeters != null && _distanceMeters! <= 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: context.garraColors.brandPrestige.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.place_rounded,
                    color: context.garraColors.brandPrestige,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.name,
                        style: TextStyle(
                          color: context.garraColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _translatePointType(point.type),
                        style: TextStyle(
                          color: context.garraColors.brandPrestige,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (point.description != null && point.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                point.description!,
                style: TextStyle(
                  color: context.garraColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Dirección',
              value: point.address,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.my_location_rounded,
              label: 'Coordenadas',
              value: '${point.latitude}, ${point.longitude}',
              small: true,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (point.verified)
                  const _Badge(
                    label: 'Verificado por Garra',
                    color: Colors.green,
                    icon: Icons.verified_rounded,
                  ),
                if (point.sponsor)
                  const _Badge(
                    label: 'Sponsor',
                    color: AppTheme.gold,
                    icon: Icons.workspace_premium_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasCheckIn)
              _CheckInDone(checkIn: checkIn)
            else if (_loadingDistance)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Calculando distancia...',
                  style: TextStyle(color: context.garraColors.brandPrestige),
                ),
              ),

            if (_distanceMeters != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _distanceMeters! <= 100
                        ? context.garraColors.success.withValues(alpha: 0.12)
                        : context.garraColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _distanceMeters! <= 100
                          ? context.garraColors.success.withValues(alpha: 0.35)
                          : context.garraColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _distanceMeters! <= 100
                        ? 'Estás a ${_distanceMeters!.toStringAsFixed(0)} m. Puedes hacer check-in.'
                        : 'Estás a ${(_distanceMeters! / 1000).toStringAsFixed(2)} km. Estás fuera del rango permitido.',
                    style: TextStyle(
                      color: _distanceMeters! <= 100
                          ? context.garraColors.success
                          : context.garraColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

            FilledButton.icon(
              onPressed: (_submitting || !canCheckIn) ? null : _createCheckIn,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.burgundy,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(canCheckIn ? 'Hacer check-in' : 'Fuera de rango'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openReviews(point.id, point.name),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Opiniones de la comunidad'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReviews(String pointId, String name) async {
    final service = RetentionService();
    BusinessRatingSummary? summary;
    try {
      summary = await service.businessReviews(pointId);
    } catch (_) {}
    if (!mounted) return;
    final ratingController = TextEditingController();
    final commentController = TextEditingController();
    var checkingPresence = false;
    String? presenceMessage;
    var canReview = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, updateSheet) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(summary?.label ?? 'Opiniones de la comunidad'),
                if (summary != null && summary.averageRating != null)
                  Text(
                    '★ ${summary.averageRating!.toStringAsFixed(1)} · ${summary.reviewCount} opiniones',
                  ),
                const SizedBox(height: 12),
                ...(summary?.reviews ?? const <BusinessReviewModel>[])
                    .take(5)
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${r.username ?? 'Fan'} · ${'★' * r.rating}${r.comment != null ? ' — ${r.comment}' : ''}',
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                if (!canReview) OutlinedButton.icon(
                  onPressed: checkingPresence ? null : () async {
                    updateSheet(() {
                      checkingPresence = true;
                      presenceMessage = null;
                    });
                    final location = await AppLocationService().getCurrentLocation();
                    if (!ctx.mounted) return;
                    final distance = location.latitude == null || location.longitude == null
                        ? null : Geolocator.distanceBetween(
                            location.latitude!, location.longitude!,
                            widget.point.latitude, widget.point.longitude);
                    updateSheet(() {
                      checkingPresence = false;
                      canReview = distance != null &&
                          distance <= widget.point.checkinRadiusMeters;
                      presenceMessage = canReview ? null :
                          distance == null ? location.message :
                          'Debes estar cerca del negocio para opinar.';
                    });
                  },
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(checkingPresence ? 'Comprobando ubicación...' : 'Opinar aquí'),
                ),
                if (presenceMessage != null) Text(presenceMessage!),
                if (canReview) TextField(
                  controller: ratingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tu nota (1-5)'),
                ),
                if (canReview) TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comentario (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                if (canReview) FilledButton(
                  onPressed: () async {
                    final rating = int.tryParse(ratingController.text.trim());
                    if (rating == null || rating < 1 || rating > 5) return;
                    try {
                      final location = await AppLocationService().getCurrentLocation();
                      if (location.latitude == null || location.longitude == null) {
                        throw StateError('Location unavailable');
                      }
                      await service.upsertBusinessReview(
                        pointId,
                        rating: rating,
                        comment: commentController.text,
                        latitude: location.latitude!,
                        longitude: location.longitude!,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opinión guardada')),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Debes estar cerca del negocio para opinar',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Publicar opinión'),
                ),
              ],
            ),
          ),
        );
      }),
    );
    ratingController.dispose();
    commentController.dispose();
  }
}

class _CheckInDone extends StatelessWidget {
  const _CheckInDone({required this.checkIn});

  final CheckInModel checkIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final isValid = checkIn.status == 'VALID';
    final title = isValid ? 'Check-in realizado' : 'Check-in rechazado';
    final color = isValid ? colors.success : colors.warning;
    final icon = isValid ? Icons.check_circle_rounded : Icons.warning_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(label: title, color: color, icon: icon),
          const SizedBox(height: 10),
          Text(
            '+${checkIn.pointsEarned} puntos crema',
            style: TextStyle(
              color: colors.success,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Estado: ${_translateCheckInStatus(checkIn.status)}',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fecha: ${formatDateTime(checkIn.createdAt)}',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.small = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: context.garraColors.brandPrestige,
          size: small ? 16 : 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: small ? 12 : 13, height: 1.3),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: context.garraColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: context.garraColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.place_outlined,
          color: context.garraColors.brandPrestige,
          size: 54,
        ),
        const SizedBox(height: 18),
        Text(
          'No hay puntos crema disponibles',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.garraColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Cuando existan puntos activos, aparecerán aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.garraColors.textSecondary,
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

String _translatePointType(String type) {
  switch (type) {
    case 'STADIUM':
      return 'Estadio';
    case 'BUSINESS':
      return 'Negocio crema';
    case 'MEETING_POINT':
      return 'Punto de encuentro';
    case 'BANDERAZO':
      return 'Banderazo';
    case 'BAR':
      return 'Bar';
    default:
      return type;
  }
}

String _translateCheckInStatus(String status) {
  switch (status) {
    case 'VALID':
      return 'Válido';
    case 'REJECTED':
      return 'Rechazado';
    default:
      return status;
  }
}
