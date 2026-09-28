/// ANALYTICS_12: compact Spanish count used by social metrics (views).
///
/// 999 -> "999", 1000 -> "1 mil", 1250 -> "1.2 mil", 10500 -> "10 mil",
/// 1000000 -> "1 M", 1500000 -> "1.5 M". Decimals are truncated (never
/// rounded up), so "1.9 mil" is never shown for fewer than 1900 items.
String formatGarraCount(int value) {
  if (value <= 0) return '0';
  if (value < 1000) return '$value';
  if (value < 1000000) return '${_compact(value, 1000)} mil';
  return '${_compact(value, 1000000)} M';
}

String _compact(int value, int unit) {
  final whole = value ~/ unit;
  if (whole >= 10) return '$whole';
  final tenth = (value % unit) * 10 ~/ unit;
  return tenth == 0 ? '$whole' : '$whole.$tenth';
}
