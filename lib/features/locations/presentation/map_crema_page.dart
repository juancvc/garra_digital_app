import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/checkin_model.dart';
import '../data/crema_business_engagement_service.dart';
import '../data/crema_point_model.dart';
import '../data/create_checkin_request.dart';
import 'providers/location_provider.dart';
import 'widgets/garra_checkin_success.dart';

class MapCremaPage extends ConsumerStatefulWidget {
  const MapCremaPage({super.key, this.matchId});

  final String? matchId;

  @override
  ConsumerState<MapCremaPage> createState() => _MapCremaPageState();
}

class _MapCremaPageState extends ConsumerState<MapCremaPage> {
  static const LatLng _limaLatLng = LatLng(-12.0464, -77.0428);

  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  CremaPointModel? _selectedPoint;
  final _engagement = CremaBusinessEngagementService();
  final Set<String> _followingIds = {};

  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    try {
      final ids = await _engagement.followingIds();
      if (!mounted) return;
      setState(() {
        _followingIds
          ..clear()
          ..addAll(ids);
      });
    } catch (_) {}
  }

  Future<void> _toggleFollow(CremaPointModel point) async {
    try {
      if (_followingIds.contains(point.id)) {
        await _engagement.unfollow(point.id);
        setState(() => _followingIds.remove(point.id));
      } else {
        await _engagement.follow(point.id);
        setState(() => _followingIds.add(point.id));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el seguimiento')),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    final gpsResult = await AppLocationService().getCurrentLocation();

    if (!mounted) return;

    if (gpsResult.latitude == null || gpsResult.longitude == null) {
      setState(() => _currentLatLng = null);
      return;
    }

    final current = LatLng(gpsResult.latitude!, gpsResult.longitude!);

    setState(() => _currentLatLng = current);

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: current, zoom: 15)),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    if (_currentLatLng == null) {
      await _loadCurrentLocation();
    }

    final target = _currentLatLng ?? _limaLatLng;

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: _currentLatLng == null ? 12 : 16),
      ),
    );
  }

  Future<void> _selectPoint(CremaPointModel point) async {
    setState(() => _selectedPoint = point);

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(point.latitude, point.longitude),
          zoom: 16,
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(CremaPointModel point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${point.latitude},${point.longitude}'
      '&travelmode=driving',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      _showSnackBar(
        message: 'No se pudo abrir Google Maps',
        backgroundColor: Colors.orange,
      );
    }
  }

  Future<void> _createCheckIn(CremaPointModel point) async {
    if (_checkingIn) return;

    setState(() => _checkingIn = true);

    try {
      final gpsResult = await AppLocationService().getCurrentLocation();

      if (!mounted) return;

      if (gpsResult.latitude == null || gpsResult.longitude == null) {
        _showSnackBar(
          message: gpsResult.message.isNotEmpty
              ? gpsResult.message
              : 'No se pudo obtener tu ubicación actual',
          backgroundColor: Colors.orange,
        );
        return;
      }

      setState(() {
        _currentLatLng = LatLng(gpsResult.latitude!, gpsResult.longitude!);
      });

      final service = ref.read(locationServiceProvider);

      final result = await service.createCheckIn(
        CreateCheckInRequest(
          cremaPointId: point.id,
          latitude: gpsResult.latitude!,
          longitude: gpsResult.longitude!,
          matchId: widget.matchId,
          accuracyMeters: gpsResult.accuracyMeters,
        ),
      );

      if (!mounted) return;

      if (result.success && result.checkIn != null) {
        await _showCheckInSuccess(result.checkIn!);
      } else {
        _showSnackBar(
          message: _normalizeCheckInMessage(result.message),
          backgroundColor: Colors.orange,
        );
      }

      ref.invalidate(myCheckInsProvider);
      ref.invalidate(cremaPointsProvider);
    } catch (_) {
      if (!mounted) return;

      _showSnackBar(
        message: 'No se pudo registrar el check-in',
        backgroundColor: Colors.orange,
      );
    } finally {
      if (mounted) {
        setState(() => _checkingIn = false);
      }
    }
  }

  Set<Marker> _buildMarkers(List<CremaPointModel> points) {
    final selectedId = _selectedPoint?.id;

    final pointMarkers = points.map((point) {
      final selected = point.id == selectedId;

      return Marker(
        markerId: MarkerId(point.id),
        position: LatLng(point.latitude, point.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          selected ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: point.name,
          snippet: _translatePointType(point.type),
        ),
        onTap: () => _selectPoint(point),
      );
    }).toSet();

    if (_currentLatLng == null) {
      return pointMarkers;
    }

    return {
      ...pointMarkers,
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Mi ubicación'),
      ),
    };
  }

  double? _distanceToPoint(CremaPointModel point) {
    if (_currentLatLng == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      point.latitude,
      point.longitude,
    );
  }

  String _normalizeCheckInMessage(String message) {
    final normalized = message.toLowerCase();

    if (message.contains('Valid check-in already exists')) {
      return 'Ya tienes un check-in válido en este punto durante las últimas 12 horas';
    }

    if (message.contains('Check-in processed successfully')) {
      return 'Check-in procesado correctamente';
    }

    if (normalized.contains('too far') || normalized.contains('outside')) {
      return 'Estás fuera del rango permitido para este punto';
    }

    return message;
  }

  Future<void> _showCheckInSuccess(CheckInModel checkIn) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          content: GarraCheckInSuccess(
            checkIn: checkIn,
            onDismiss: () => Navigator.of(ctx).pop(),
          ),
        );
      },
    );
  }

  void _showSnackBar({
    required String message,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(cremaPointsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/ruta-templo'),
        ),
        title: const Text(
          'Mapa Crema',
          style: TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: pointsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.gold),
          ),
          error: (_, _) => GarraErrorState(
            title: 'No pudimos cargar el Mapa Crema',
            onRetry: () => ref.invalidate(cremaPointsProvider),
          ),
          data: (points) {
            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng ?? _limaLatLng,
                    zoom: _currentLatLng == null ? 12 : 15,
                  ),
                  markers: _buildMarkers(points),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;

                    if (_currentLatLng != null) {
                      _moveToCurrentLocation();
                    }
                  },
                  onTap: (_) {
                    if (_selectedPoint != null) {
                      setState(() => _selectedPoint = null);
                    }
                  },
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: _FloatingMapButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Mi ubicación',
                    onPressed: _moveToCurrentLocation,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 96,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _selectedPoint == null
                        ? const SizedBox.shrink()
                        : _SelectedPointCard(
                            key: ValueKey(_selectedPoint!.id),
                            point: _selectedPoint!,
                            distanceMeters: _distanceToPoint(_selectedPoint!),
                            matchContext:
                                widget.matchId != null &&
                                widget.matchId!.isNotEmpty,
                            checkingIn: _checkingIn,
                            following: _followingIds.contains(
                              _selectedPoint!.id,
                            ),
                            onClose: () {
                              setState(() => _selectedPoint = null);
                            },
                            onDirections: () =>
                                _openGoogleMaps(_selectedPoint!),
                            onCheckIn: () => _createCheckIn(_selectedPoint!),
                            onFollow:
                                _selectedPoint!.type.toUpperCase() ==
                                        'BUSINESS' &&
                                    _selectedPoint!.verified
                                ? () => _toggleFollow(_selectedPoint!)
                                : null,
                            onOpenStore:
                                (_selectedPoint!.marketplaceStoreSlug ?? '')
                                    .isEmpty
                                ? null
                                : () => context.push(
                                    '/marketplace/stores/${_selectedPoint!.marketplaceStoreSlug}',
                                  ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectedPointCard extends StatelessWidget {
  const _SelectedPointCard({
    required this.point,
    required this.distanceMeters,
    required this.matchContext,
    required this.checkingIn,
    required this.following,
    required this.onClose,
    required this.onDirections,
    required this.onCheckIn,
    this.onFollow,
    this.onOpenStore,
    super.key,
  });

  final CremaPointModel point;
  final double? distanceMeters;
  final bool matchContext;
  final bool checkingIn;
  final bool following;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final VoidCallback onCheckIn;
  final VoidCallback? onFollow;
  final VoidCallback? onOpenStore;

  bool get _isInRange {
    final distance = distanceMeters;
    final radius = point.checkinRadiusMeters;
    return distance != null && distance <= radius;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.gold.withOpacity(0.24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.48),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: AppTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.cream,
                            fontSize: 17,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _translatePointType(point.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _InfoLine(icon: Icons.location_on_outlined, text: point.address),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.social_distance_rounded,
                text: _formatDistance(distanceMeters),
              ),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.radar_rounded,
                text: 'Radio de check-in: ${point.checkinRadiusMeters} m',
              ),
              if (matchContext) ...[
                const SizedBox(height: 8),
                const _InfoLine(
                  icon: Icons.sports_soccer_rounded,
                  text: 'Check-in de fecha activa',
                ),
              ],
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (point.verified)
                    const _PointBadge(
                      label: 'Verificado por Garra',
                      color: Colors.green,
                      icon: Icons.verified_rounded,
                    ),
                  if (point.sponsor)
                    const _PointBadge(
                      label: 'Sponsor',
                      color: AppTheme.gold,
                      icon: Icons.workspace_premium_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: onDirections,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.gold,
                          side: BorderSide(
                            color: AppTheme.gold.withOpacity(0.55),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: const Text(
                          'Cómo llegar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: _isInRange && !checkingIn ? onCheckIn : null,
                        icon: checkingIn
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.burgundy,
                                ),
                              )
                            : Icon(
                                _isInRange
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.block_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isInRange ? 'Check-in' : 'Fuera de rango',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (onFollow != null || onOpenStore != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    if (onFollow != null)
                      OutlinedButton(
                        onPressed: onFollow,
                        child: Text(following ? 'Siguiendo' : 'Seguir'),
                      ),
                    if (onOpenStore != null)
                      OutlinedButton(
                        onPressed: onOpenStore,
                        child: const Text('Ver tienda'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDistance(double? meters) {
    if (meters == null) {
      return 'Ubicación no disponible';
    }

    if (meters < 1000) {
      return 'Estás a ${meters.round()} m';
    }

    return 'Estás a ${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.gold, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 12,
              height: 1.28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(18),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.45),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.gold.withOpacity(0.22)),
            ),
            child: Icon(icon, color: AppTheme.gold),
          ),
        ),
      ),
    );
  }
}

class _PointBadge extends StatelessWidget {
  const _PointBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
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
