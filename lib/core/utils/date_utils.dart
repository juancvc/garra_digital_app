import 'package:intl/intl.dart';

/// Parses an API timestamp as an absolute instant.
/// Values without a zone are treated as UTC, then callers display them locally.
DateTime? parseGarraInstant(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  if (parsed.isUtc) return parsed;
  final hasZone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
  if (hasZone) return parsed.toUtc();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

String formatDateTime(String isoDate) {
  final instant = parseGarraInstant(isoDate);
  if (instant == null) return isoDate;
  return DateFormat(
    "EEEE d 'de' MMMM - h:mm a",
    'es_PE',
  ).format(instant.toLocal());
}

String formatGarraRelativeTime(String value, {DateTime? now}) {
  final instant = parseGarraInstant(value);
  if (instant == null) return 'ahora';
  final reference = (now ?? DateTime.now()).toUtc();
  final difference = reference.difference(instant);
  if (difference.isNegative || difference.inMinutes < 1) return 'ahora';
  if (difference.inMinutes < 60) return 'hace ${difference.inMinutes} min';
  if (difference.inHours < 24) return 'hace ${difference.inHours} h';
  if (difference.inDays < 7) return 'hace ${difference.inDays} d';
  if (difference.inDays < 30) return 'hace ${difference.inDays ~/ 7} sem';
  if (difference.inDays < 365) return 'hace ${difference.inDays ~/ 30} mes';
  return 'hace ${difference.inDays ~/ 365} a';
}
