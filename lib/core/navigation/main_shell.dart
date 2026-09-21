import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    required this.child,
    super.key,
  });

  final Widget child;

  static const _routes = [
    '/home',
    '/comunidad',
    '/ruta-templo',
    '/marketplace',
    '/passport',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/comunidad') ||
        location.startsWith('/muro-crema') ||
        location.startsWith('/clans') ||
        location.startsWith('/solidaria')) {
      return 1;
    }
    if (location.startsWith('/ruta-templo')) {
      return 2;
    }
    if (location.startsWith('/marketplace')) {
      return 3;
    }
    if (location.startsWith('/passport') ||
        location.startsWith('/history') ||
        location.startsWith('/historial')) {
      return 4;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    if (index == _currentIndex(context)) return;
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border(
            top: BorderSide(
              color: AppTheme.cream.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF111111),
            selectedItemColor: AppTheme.gold,
            unselectedItemColor: Colors.white54,
            selectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            onTap: (index) => _onTap(context, index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.forum_rounded),
                label: 'Comunidad',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                label: 'Mapa',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.storefront_outlined),
                label: 'Market',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
