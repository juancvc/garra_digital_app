const List<(String, String)> garraCountries = [
  ('PE', 'Perú'),
  ('AR', 'Argentina'),
  ('BO', 'Bolivia'),
  ('BR', 'Brasil'),
  ('CL', 'Chile'),
  ('CO', 'Colombia'),
  ('EC', 'Ecuador'),
  ('ES', 'España'),
  ('MX', 'México'),
  ('US', 'Estados Unidos'),
  ('UY', 'Uruguay'),
  ('VE', 'Venezuela'),
];

String countryName(String? code) {
  final normalized = code?.trim().toUpperCase() ?? '';
  if (normalized.isEmpty) return '';
  for (final country in garraCountries) {
    if (country.$1 == normalized) return country.$2;
  }
  return normalized;
}

String clanVisibilityLabel(String? visibility) {
  switch (visibility?.trim().toUpperCase()) {
    case 'PRIVATE':
      return 'Privada';
    case 'PUBLIC':
      return 'Pública';
    default:
      return 'Pública';
  }
}
