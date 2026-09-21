/// Semantic version compare (MAJOR.MINOR.PATCH[+build ignored]).
class SemVer {
  SemVer(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static SemVer parse(String raw) {
    final cleaned = raw.trim().split('+').first.split('-').first;
    final parts = cleaned.split('.');
    int maj = 0, min = 0, pat = 0;
    if (parts.isNotEmpty) maj = int.tryParse(parts[0]) ?? 0;
    if (parts.length > 1) min = int.tryParse(parts[1]) ?? 0;
    if (parts.length > 2) pat = int.tryParse(parts[2]) ?? 0;
    return SemVer(maj, min, pat);
  }

  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(SemVer o) => compareTo(o) < 0;
  bool operator >(SemVer o) => compareTo(o) > 0;
  bool operator <=(SemVer o) => compareTo(o) <= 0;
  bool operator >=(SemVer o) => compareTo(o) >= 0;

  @override
  String toString() => '$major.$minor.$patch';
}

enum AppVersionStatus { supported, updateAvailable, updateRequired }

AppVersionStatus evaluateVersion({
  required String installed,
  required String minimumSupported,
  required String latest,
}) {
  final current = SemVer.parse(installed);
  final min = SemVer.parse(minimumSupported);
  final lat = SemVer.parse(latest);
  if (current < min) return AppVersionStatus.updateRequired;
  if (current < lat) return AppVersionStatus.updateAvailable;
  return AppVersionStatus.supported;
}
