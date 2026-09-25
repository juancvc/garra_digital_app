import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the Garra Primordial intro has already played.
class FirstLaunchExperienceService {
  FirstLaunchExperienceService({IntroFlagStore? store})
    : _store = store ?? SharedPrefsIntroFlagStore();

  static const introSeenKey = 'garra_intro_seen_v1';

  final IntroFlagStore _store;

  Future<bool> hasSeenIntro() => _store.read(introSeenKey);

  Future<void> markIntroSeen() => _store.write(introSeenKey, true);

  /// Clears only the intro flag. Auth and secure storage stay untouched.
  Future<void> resetIntro() => _store.remove(introSeenKey);
}

abstract class IntroFlagStore {
  Future<bool> read(String key);
  Future<void> write(String key, bool value);
  Future<void> remove(String key);
}

class SharedPrefsIntroFlagStore implements IntroFlagStore {
  @override
  Future<bool> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> write(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

class MemoryIntroFlagStore implements IntroFlagStore {
  final Map<String, Object> values = {};

  @override
  Future<bool> read(String key) async => values[key] == true;

  @override
  Future<void> write(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
