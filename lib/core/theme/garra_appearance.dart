import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'garra_semantic_colors.dart';

/// User-facing appearance. Stored locally and resolved once for MaterialApp.
enum GarraAppearance { system, crema, nocheMonumental }

ThemeMode themeModeFor(GarraAppearance appearance) {
  return switch (appearance) {
    GarraAppearance.system => ThemeMode.system,
    GarraAppearance.crema => ThemeMode.light,
    GarraAppearance.nocheMonumental => ThemeMode.dark,
  };
}

/// Light icons on Noche Monumental, dark icons on Crema.
SystemUiOverlayStyle garraOverlayStyle({
  required Brightness brightness,
  required Color navigationBar,
}) {
  final lightIcons = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
    statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: navigationBar,
    systemNavigationBarIconBrightness: lightIcons
        ? Brightness.light
        : Brightness.dark,
  );
}

class GarraThemeStore {
  GarraThemeStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const storageKey = 'garra_appearance';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  Future<GarraAppearance> read() async {
    final raw = (await _prefs).getString(storageKey);
    return GarraAppearance.values.asNameMap()[raw] ?? GarraAppearance.system;
  }

  Future<void> write(GarraAppearance appearance) async {
    await (await _prefs).setString(storageKey, appearance.name);
  }
}

class GarraAppearanceNotifier extends Notifier<GarraAppearance> {
  GarraAppearanceNotifier([this.seed = GarraAppearance.system]);

  final GarraAppearance seed;

  @override
  GarraAppearance build() => seed;

  Future<void> select(GarraAppearance appearance) async {
    state = appearance;
    try {
      await GarraThemeStore().write(appearance);
    } catch (_) {}
  }
}

final garraAppearanceProvider =
    NotifierProvider<GarraAppearanceNotifier, GarraAppearance>(
      () => GarraAppearanceNotifier(),
    );

/// Applies the resolved overlay without each screen setting its own.
class GarraSystemOverlay extends StatelessWidget {
  const GarraSystemOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.garraColors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: garraOverlayStyle(
        brightness: theme.brightness,
        navigationBar: colors.background,
      ),
      child: child,
    );
  }
}
