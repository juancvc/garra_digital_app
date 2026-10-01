import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/location/location_service.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';

class PickBusinessLocationPage extends StatefulWidget {
  const PickBusinessLocationPage({
    super.key,
    this.initialLat = -12.0553,
    this.initialLng = -77.0379,
    this.locationService,
  });

  final double initialLat;
  final double initialLng;
  final AppLocationService? locationService;

  @override
  State<PickBusinessLocationPage> createState() =>
      _PickBusinessLocationPageState();
}

class _PickBusinessLocationPageState extends State<PickBusinessLocationPage> {
  late LatLng _point;
  bool _resolving = false;
  late final AppLocationService _locationService =
      widget.locationService ?? AppLocationService();

  @override
  void initState() {
    super.initState();
    _point = LatLng(widget.initialLat, widget.initialLng);
  }

  Future<void> _confirm() async {
    if (_resolving) return;
    setState(() => _resolving = true);
    final label = await _locationService.resolveSocialArea(
      _point.latitude,
      _point.longitude,
    );
    if (!mounted) return;
    context.pop(<String, dynamic>{
      'lat': _point.latitude,
      'lng': _point.longitude,
      'label': label ?? 'Zona seleccionada en mapa',
    });
  }

  Future<void> _useCurrentLocation() async {
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (result.latitude != null && result.longitude != null) {
      setState(() => _point = LatLng(result.latitude!, result.longitude!));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Ubicación del negocio'),
        backgroundColor: const Color(GarraColors.charcoal),
        actions: [
          TextButton(
            onPressed: _resolving ? null : _confirm,
            child: Text(_resolving ? 'Resolviendo...' : 'Confirmar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _point, zoom: 15),
              markers: {
                Marker(
                  markerId: const MarkerId('biz'),
                  position: _point,
                  draggable: true,
                  onDragEnd: (p) => setState(() => _point = p),
                ),
              },
              onTap: (p) => setState(() => _point = p),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(GarraSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Toca el mapa o arrastra el pin para elegir el punto del negocio.',
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Usar mi ubicación actual'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
