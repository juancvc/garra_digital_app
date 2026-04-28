import 'package:intl/intl.dart';

String formatDateTime(String isoDate) {
  final date = DateTime.parse(isoDate);

  return DateFormat(
    "EEEE d 'de' MMMM - h:mm a",
    'es_PE',
  ).format(date);
}