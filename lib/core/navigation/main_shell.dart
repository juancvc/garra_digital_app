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
    '/polla',
    '/ruta-templo',
    '/muro-crema',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    if (location.startsWith('/polla')) {
      return 1;
    }

    if (location.startsWith('/ruta-templo')) {
      return 2;
    }

    if (location.startsWith('/muro-crema')) {
      return 3;
    }

    return 0;
  }

  void _onTap(BuildContext context, int index) {
    final currentIndex = _currentIndex(context);

    if (index == currentIndex) {
      return;
    }

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
              color: AppTheme.cream.withOpacity(0.08),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
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
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            onTap: (index) => _onTap(context, index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fact_check_rounded),
                label: 'Polla',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.route_rounded),
                label: 'Ruta',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.forum_rounded),
                label: 'Muro',
              ),
            ],
          ),
        ),
      ),
    );
  }
}