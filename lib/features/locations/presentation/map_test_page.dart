import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapTestPage extends StatelessWidget {
  const MapTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa Test')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(-12.0464, -77.0428), // Lima
          zoom: 14,
        ),
      ),
    );
  }
}