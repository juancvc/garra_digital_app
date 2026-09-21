import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';

class PickBusinessLocationPage extends StatefulWidget {
  const PickBusinessLocationPage({
    super.key,
    this.initialLat = -12.0553,
    this.initialLng = -77.0379,
  });

  final double initialLat;
  final double initialLng;

  @override
  State<PickBusinessLocationPage> createState() =>
      _PickBusinessLocationPageState();
}

class _PickBusinessLocationPageState extends State<PickBusinessLocationPage> {
  late LatLng _point;

  @override
  void initState() {
    super.initState();
    _point = LatLng(widget.initialLat, widget.initialLng);
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
            onPressed: () => context.pop({
              'lat': _point.latitude,
              'lng': _point.longitude,
            }),
            child: const Text('Usar'),
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
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(GarraSpacing.md),
            child: Text(
              'Toca el mapa o arrastra el pin.\n${_point.latitude.toStringAsFixed(5)}, ${_point.longitude.toStringAsFixed(5)}',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
