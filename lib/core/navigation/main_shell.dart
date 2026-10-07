import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/create_action_sheet.dart';
import '../../features/chat/presentation/chat_unread_badge.dart';
import 'home_back_scroll.dart';
import '../discovery/garra_discovery_tip.dart';
import '../design/garra_colors.dart';
import '../theme/garra_semantic_colors.dart';

/// Main shell — Inicio / Comunidad / Crear / Centro Garra / Explorar / Perfil
class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  int get _navIndex {
    // Branches: 0 home, 1 comunidad, 2 centro, 3 explorar, 4 passport
    // Nav slots: 0 home, 1 comunidad, 2 crear, 3 centro, 4 explorar, 5 perfil
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.garraColors;
    final homeScrolled = ref.watch(homeBackScrollProvider);
    final chatUnread = ref.watch(chatUnreadTotalProvider);
    return ChatUnreadReconciler(child: PopScope(
      canPop: navigationShell.currentIndex == 0 && !homeScrolled,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        } else if (homeScrolled) {
          ref.read(homeBackScrollProvider.notifier).scrollToTop();
        }
      },
      child: Scaffold(
      backgroundColor: colors.background,
      body: Stack(children: [
        navigationShell,
        Positioned(left: 12, right: 12, bottom: 12,
          child: switch (navigationShell.currentIndex) {
            0 => const GarraDiscoveryTip(key: ValueKey('home-tip'),
              id: 'home.v1', title: 'Descubre Garra',
              message: 'Desde Inicio y Explorar encuentras publicaciones, personas y experiencias de la comunidad.'),
            1 => const GarraDiscoveryTip(key: ValueKey('community-tip'),
              id: 'tribuna.v1', title: 'Tu Tribuna',
              message: 'Publica, comenta y reacciona. En las comunidades también puedes conversar con otros hinchas.'),
            2 => const GarraDiscoveryTip(key: ValueKey('football-tip'),
              id: 'football.v1', title: 'Centro Garra',
              message: 'Consulta partidos, resultados y tablas. Abre un partido para entrar a su Tribuna y Chat Futbolero.'),
            3 => const GarraDiscoveryTip(key: ValueKey('explore-tip'),
              id: 'explore.v1', title: 'Explora Garra',
              message: 'Encuentra personas, negocios, Marketplace y otras experiencias de la comunidad.'),
            _ => const SizedBox.shrink(),
          }),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: const NavigationBarThemeData(
              labelTextStyle: WidgetStatePropertyAll(TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.0,
                height: 1.0,
              )),
            ),
            child: NavigationBar(
            height: 66,
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: const Color(
              GarraColors.burgundy,
            ).withValues(alpha: 0.72),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: _navIndex,
            onDestinationSelected: (i) => _onTap(context, i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: chatUnread > 0,
                  label: Text(chatUnread > 99 ? '99+' : '$chatUnread'),
                  child: const Icon(Icons.forum_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: chatUnread > 0,
                  label: Text(chatUnread > 99 ? '99+' : '$chatUnread'),
                  child: const Icon(Icons.forum_rounded),
                ),
                label: 'Comunidad',
              ),
              const NavigationDestination(
                icon: _CreateDestinationIcon(),
                selectedIcon: _CreateDestinationIcon(selected: true),
                label: 'Crear',
              ),
              const NavigationDestination(
                icon: Icon(Icons.sports_soccer_outlined),
                selectedIcon: Icon(Icons.sports_soccer),
                label: 'Centro',
              ),
              const NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Explorar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Perfil',
              ),
            ],
            ),
          ),
        ),
      ),
      ),
    ));
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
