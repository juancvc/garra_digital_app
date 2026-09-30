import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/location/location_service.dart'
    show AppLocationService, LocationResult;
import '../../../core/network/connectivity_status.dart';
import '../../locations/data/location_service.dart';
import '../../locations/data/crema_point_model.dart';
import '../data/post_location.dart';

/// A map tap is orientation only; publishing requires an explicit area label.
PostLocation confirmedPostArea(String label) => PostLocation(
    name: label.trim(), kind: 'CITY_OR_AREA');

/// Explicit post location selection. Opening this sheet never asks for GPS.
class PostLocationPicker extends StatefulWidget {
  const PostLocationPicker({super.key, this.locationService, this.gpsService,
    this.confirmCurrentLocation});
  final LocationService? locationService;
  final AppLocationService? gpsService;
  final Future<PostLocation?> Function(BuildContext, LocationResult)?
      confirmCurrentLocation;

  @override
  State<PostLocationPicker> createState() => _PostLocationPickerState();
}

class _PostLocationPickerState extends State<PostLocationPicker> {
  final _city = TextEditingController();
  late Future<List<CremaPointModel>> _points;
  bool _pointsInitialized = false;
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await (widget.gpsService ?? AppLocationService())
        .getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (!result.success || result.latitude == null || result.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    final selected = await (widget.confirmCurrentLocation?.call(context, result) ??
        Navigator.of(context).push<PostLocation>(
      MaterialPageRoute(builder: (_) => _CurrentPostLocationMap(
        latitude: result.latitude!, longitude: result.longitude!,
      )),
    ));
    if (mounted && selected != null) Navigator.of(context).pop(selected);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pointsInitialized) return;
    _pointsInitialized = true;
    final offline = ProviderScope.containerOf(context, listen: false)
        .read(connectivityStatusProvider) == NetworkConnectivity.offline;
    _points = offline ? Future.value([]) :
        (widget.locationService ?? LocationService()).getActivePoints();
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text('Agregar ubicación', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox.square(dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: const Text('Usar mi ubicación actual'),
          ),
          const Text('Confirma en el mapa qué ciudad o zona deseas publicar.'),
          TextField(
            controller: _city,
            maxLength: 160,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Ciudad o zona',
                hintText: 'Cusco, Miraflores, Lima...'),
          ),
          TextButton(
            onPressed: _city.text.trim().isEmpty ? null : () =>
              Navigator.pop(context, confirmedPostArea(_city.text)),
            child: const Text('Usar ciudad o zona'),
          ),
          const Divider(),
          const Align(alignment: Alignment.centerLeft,
              child: Text('Puntos Garra')),
          Expanded(child: FutureBuilder(
            future: _points,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text(
                    'No se pudieron cargar los puntos. Puedes indicar una ciudad o zona.'));
              }
              final points = snapshot.data ?? [];
              return ListView.builder(
                itemCount: points.length,
                itemBuilder: (context, index) {
                  final point = points[index];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(point.name),
                    subtitle: Text(point.address),
                    onTap: () => Navigator.pop(context, PostLocation(
                      name: point.name, kind: 'PLACE',
                      latitude: point.latitude, longitude: point.longitude)),
                  );
                },
              );
            },
          )),
        ]),
      ),
    ),
  );
}

Future<PostLocation?> pickPostLocation(BuildContext context,
    {LocationService? locationService, AppLocationService? gpsService,
    Future<PostLocation?> Function(BuildContext, LocationResult)?
        confirmCurrentLocation}) =>
  showModalBottomSheet<PostLocation>(
    context: context, isScrollControlled: true,
    builder: (_) => PostLocationPicker(
        locationService: locationService, gpsService: gpsService,
        confirmCurrentLocation: confirmCurrentLocation),
  );

/// GPS is local map context only. No precise coordinate leaves this screen.
class _CurrentPostLocationMap extends StatefulWidget {
  const _CurrentPostLocationMap({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;

  @override
  State<_CurrentPostLocationMap> createState() => _CurrentPostLocationMapState();
}

class _CurrentPostLocationMapState extends State<_CurrentPostLocationMap> {
  final _label = TextEditingController();
  late LatLng _selected = LatLng(widget.latitude, widget.longitude);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirmar ubicación')),
    body: Column(children: [
      Expanded(child: GoogleMap(
        initialCameraPosition: CameraPosition(target: _selected, zoom: 12),
        onTap: (point) => setState(() => _selected = point),
        markers: {Marker(markerId: const MarkerId('selected'), position: _selected)},
        myLocationButtonEnabled: false,
      )),
      SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('El mapa solo te orienta. Escribe y confirma la ciudad o zona que se mostrará; no se publicarán tus coordenadas.'),
          TextField(
            controller: _label,
            maxLength: 160,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Ciudad o zona publicable'),
          ),
          FilledButton(
            onPressed: _label.text.trim().isEmpty ? null : () => Navigator.pop(
              context, confirmedPostArea(_label.text)),
            child: const Text('Confirmar ubicación'),
          ),
        ]),
      )),
    ]),
  );
}
