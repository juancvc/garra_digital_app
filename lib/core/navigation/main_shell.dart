import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/create_action_sheet.dart';
import '../design/garra_colors.dart';
import '../theme/app_theme.dart';

/// V1 shell — Inicio / Comunidad / Crear / Explorar / Perfil
class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

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
      HapticFeedback.lightImpact();
      showCreateActionSheet(context);
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
            top: BorderSide(color: AppTheme.cream.withValues(alpha: 0.08)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                icon: _CreateDestinationIcon(),
                selectedIcon: _CreateDestinationIcon(selected: true),
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

class _CreateDestinationIcon extends StatelessWidget {
  const _CreateDestinationIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 32,
      decoration: BoxDecoration(
        color: selected
            ? const Color(GarraColors.gold)
            : const Color(GarraColors.burgundy),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(GarraColors.burgundy).withValues(alpha: 0.28),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(
        Icons.add_rounded,
        size: 25,
        color: selected
            ? const Color(GarraColors.burgundyDeep)
            : const Color(GarraColors.cream),
      ),
    );
  }
}
