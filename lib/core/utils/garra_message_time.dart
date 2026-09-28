import 'package:intl/intl.dart';

/// CHAT_V2_A: messaging timestamps, always in the device's local timezone.
///
/// Inputs come from `parseGarraInstant` (API instants, UTC); every formatter
/// converts to local time first. Requires `initializeDateFormatting('es_PE')`
/// (done in `main.dart`; tests initialize it themselves).
const String _garraLocale = 'es_PE';

/// es_PE formatter; falls back to the default locale when es_PE data was not
/// initialized (isolated widget tests) instead of throwing while building.
DateFormat _format(String pattern) {
  try {
    return DateFormat(pattern, _garraLocale);
  } on Exception {
    // intl's LocaleDataException (not exported by package:intl/intl.dart).
    return DateFormat(pattern);
  }
}

int _localDayDelta(DateTime reference, DateTime value) {
  final a = DateTime.utc(reference.year, reference.month, reference.day);
  final b = DateTime.utc(value.year, value.month, value.day);
  return a.difference(b).inDays;
}

/// True when both instants fall on the same local calendar day.
bool isSameGarraLocalDay(DateTime a, DateTime b) =>
    _localDayDelta(a.toLocal(), b.toLocal()) == 0;

/// Message time: "8:37 p. m." (no seconds, local).
String formatGarraMessageTime(DateTime value) =>
    _format('h:mm a').format(value.toLocal());

/// Inbox row time: today "8:42 p. m.", yesterday "Ayer", older "26/09/26".
String formatGarraInboxTime(DateTime? value, {DateTime? now}) {
  if (value == null) return '';
  final local = value.toLocal();
  final delta = _localDayDelta((now ?? DateTime.now()).toLocal(), local);
  if (delta <= 0) return formatGarraMessageTime(local);
  if (delta == 1) return 'Ayer';
  return _format('dd/MM/yy').format(local);
}

/// Day separator: "Hoy", "Ayer" or "sábado 26 de septiembre".
String formatGarraDaySeparator(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final delta = _localDayDelta((now ?? DateTime.now()).toLocal(), local);
  if (delta == 0) return 'Hoy';
  if (delta == 1) return 'Ayer';
  return _format("EEEE d 'de' MMMM").format(local);
}
