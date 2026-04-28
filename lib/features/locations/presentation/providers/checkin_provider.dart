import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garra_digital_app/features/locations/presentation/providers/location_provider.dart';

final myCheckInsProvider = FutureProvider((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getMyCheckIns();
});