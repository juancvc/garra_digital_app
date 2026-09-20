import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult({
    required this.success,
    required this.message,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
  });

  final bool success;
  final String message;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
}

class AppLocationService {
  Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return const LocationResult(
          success: false,
          message: 'Activa la ubicación del celular para hacer check-in.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult(
          success: false,
          message: 'Permiso de ubicación denegado.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          success: false,
          message:
          'Permiso de ubicación bloqueado. Actívalo desde configuración.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LocationResult(
        success: true,
        message: 'Ubicación obtenida correctamente.',
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      return const LocationResult(
        success: false,
        message: 'No se pudo obtener tu ubicación actual.',
      );
    }
  }
}


class LocationService {

  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static double calculateDistance(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
  }
}