import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/garra_colors.dart';
import '../theme/app_theme.dart';

/// V3 shell — Inicio / Comunidad / Crear / Explorar / Perfil
class MainShell extends StatelessWidget {
  const MainShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  int get _navIndex {
    // Branches: 0 home, 1 comunidad, 2 explorar, 3 passport
    // Nav slots: 0 home, 1 comunidad, 2 crear, 3 explorar, 4 perfil
    final b = navigationShell.currentIndex;
    if (b >= 2) return b + 1;
    return b;
  }

  void _onTap(BuildContext context, int index) {
    if (index == 2) {
      context.push('/comunidad/compose');
      return;
    }
    final branch = index > 2 ? index - 1 : index;
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(GarraColors.surface),
          border: Border(
            top: BorderSide(
              color: AppTheme.cream.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _navIndex,
            onDestinationSelected: (i) => _onTap(context, i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum_rounded),
                label: 'Comunidad',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline, size: 30),
                selectedIcon: Icon(Icons.add_circle, size: 30),
                label: 'Crear',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Explorar',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
