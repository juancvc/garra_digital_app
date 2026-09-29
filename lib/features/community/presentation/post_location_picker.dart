import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_status.dart';
import '../../locations/data/location_service.dart';
import '../../locations/data/crema_point_model.dart';
import '../data/post_location.dart';

/// Explicit post location selection. Opening this sheet never asks for GPS.
class PostLocationPicker extends StatefulWidget {
  const PostLocationPicker({super.key, this.locationService});
  final LocationService? locationService;

  @override
  State<PostLocationPicker> createState() => _PostLocationPickerState();
}

class _PostLocationPickerState extends State<PostLocationPicker> {
  final _city = TextEditingController();
  late Future<List<CremaPointModel>> _points;
  bool _pointsInitialized = false;

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
          TextField(
            controller: _city,
            maxLength: 160,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Ciudad o zona',
                hintText: 'Cusco, Miraflores, Lima...'),
          ),
          TextButton(
            onPressed: _city.text.trim().isEmpty ? null : () =>
              Navigator.pop(context, PostLocation(
                name: _city.text.trim(), kind: 'CITY_OR_AREA')),
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
    {LocationService? locationService}) =>
  showModalBottomSheet<PostLocation>(
    context: context, isScrollControlled: true,
    builder: (_) => PostLocationPicker(locationService: locationService),
  );
