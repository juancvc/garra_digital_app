/// Uses the stored business point as the destination. The user's position is
/// resolved by the external maps app, never sent to Garra's backend.
Uri businessDirectionsUri(double latitude, double longitude) => Uri.https(
  'www.google.com',
  '/maps/dir/',
  {
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'driving',
  },
);

/// Old records can contain a coordinate pair as their public address.
String publicBusinessArea(String address) {
  final value = address.trim();
  if (RegExp(r'^-?\d{1,2}(?:\.\d+)?,\s*-?\d{1,3}(?:\.\d+)?$')
      .hasMatch(value)) {
    return 'Ubicación disponible en el mapa';
  }
  return value;
}
