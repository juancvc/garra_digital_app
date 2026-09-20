import 'package:garra_digital_app/features/auth/presentation/complete_profile_page.dart';
import 'package:garra_digital_app/features/community/presentation/muro_crema_page.dart';
import 'package:garra_digital_app/features/notifications/presentation/notifications_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/passport_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/profile_edit_screen.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/locations/presentation/ruta_al_templo_page.dart';
import '../../features/predictions/presentation/polla_page.dart';
import '../../features/ranking/presentation/ranking_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../navigation/main_shell.dart';
import '../storage/secure_storage_service.dart';
import '../../features/locations/presentation/map_crema_page.dart';
import '../../features/locations/presentation/historial_crema_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final storage = SecureStorageService();
    final hasToken = await storage.hasToken();

    final currentPath = state.uri.path;
    final isLogin = currentPath == '/login';
    final isSplash = currentPath == '/splash';
    final isRegister = currentPath == '/register';

    if (isSplash) {
      return null;
    }

    if (!hasToken && !isLogin && !isRegister) {
      return '/login';
    }

    if (hasToken && (isLogin || isRegister)) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/complete-profile',
      builder: (context, state) => const CompleteProfilePage(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/passport',
          name: 'passport',
          builder: (context, state) => const PassportScreen(),
        ),
        GoRoute(
          path: '/passport/edit',
          name: 'passport-edit',
          builder: (context, state) => const ProfileEditScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/polla',
          name: 'polla',
          builder: (context, state) => const PollaPage(),
        ),
        GoRoute(
          path: '/ruta-templo',
          name: 'ruta-templo',
          builder: (context, state) => const RutaAlTemploPage(),
        ),
        GoRoute(
          path: '/muro-crema',
          name: 'muro-crema',
          builder: (context, state) => const MuroCremaPage(),
        ),
        GoRoute(
          path: '/ranking',
          name: 'ranking',
          builder: (context, state) => const RankingPage(),
        ),
        GoRoute(
          path: '/mapa-crema',
          name: 'mapa-crema',
          builder: (context, state) => const MapCremaPage(),
        ),
        GoRoute(
          path: '/historial-crema',
          name: 'historial-crema',
          builder: (context, state) => const HistorialCremaPage(),
        ),
      ],
    ),
  ],
);
