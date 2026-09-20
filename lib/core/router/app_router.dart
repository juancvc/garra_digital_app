import 'package:garra_digital_app/features/auth/presentation/complete_profile_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_detail_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_invitations_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_manage_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_polla_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_ranking_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_tribuna_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clans_page.dart';
import 'package:garra_digital_app/features/community/presentation/muro_crema_page.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/history/presentation/history_page.dart';
import 'package:garra_digital_app/features/history/presentation/year_recap_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/favorites_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/listing_detail_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_dashboard_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_listing_form_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_onboarding_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/store_page.dart';
import 'package:garra_digital_app/features/missions/presentation/missions_page.dart';
import 'package:garra_digital_app/features/notifications/presentation/notifications_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/passport_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/profile_edit_screen.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/locations/presentation/ruta_al_templo_page.dart';
import '../../features/polla/presentation/matchday_polls_page.dart';
import '../../features/polla/presentation/polla_page.dart';
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
          path: '/history',
          name: 'history',
          builder: (context, state) => const HistoryPage(),
        ),
        GoRoute(
          path: '/history/year/:year',
          name: 'history-year',
          builder: (context, state) {
            final raw = state.pathParameters['year'] ?? '';
            final year = int.tryParse(raw) ?? DateTime.now().year;
            return YearRecapPage(year: year);
          },
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
          path: '/polla/:matchId',
          name: 'polla-match',
          builder: (context, state) {
            final matchId = state.pathParameters['matchId'] ?? '';
            return PollaPage(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/matchday/:matchId',
          name: 'matchday',
          builder: (context, state) {
            final matchId = state.pathParameters['matchId'] ?? '';
            return MatchdayPollsPage(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/matchday/:matchId/polls',
          name: 'matchday-polls',
          builder: (context, state) {
            final matchId = state.pathParameters['matchId'] ?? '';
            return MatchdayPollsPage(matchId: matchId);
          },
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
          path: '/muro-crema/posts/:id',
          name: 'muro-crema-post-detail',
          builder: (context, state) {
            final postId = state.pathParameters['id'] ?? '';
            return PostDetailScreen(postId: postId);
          },
        ),
        GoRoute(
          path: '/ranking',
          name: 'ranking',
          builder: (context, state) => const RankingPage(),
        ),
        GoRoute(
          path: '/missions',
          name: 'missions',
          builder: (context, state) {
            final matchId = state.uri.queryParameters['matchId'];
            return MissionsPage(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/clans',
          name: 'clans',
          builder: (context, state) => const ClansPage(),
        ),
        GoRoute(
          path: '/clans/invitations',
          name: 'clans-invitations',
          builder: (context, state) => const ClanInvitationsPage(),
        ),
        GoRoute(
          path: '/clans/ranking',
          name: 'clans-ranking',
          builder: (context, state) => const ClanRankingPage(),
        ),
        GoRoute(
          path: '/clans/:slug',
          name: 'clan-detail',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return ClanDetailPage(slug: slug);
          },
        ),
        GoRoute(
          path: '/clans/:slug/tribuna',
          name: 'clan-tribuna',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return ClanTribunaPage(slug: slug);
          },
        ),
        GoRoute(
          path: '/clans/:slug/polla',
          name: 'clan-polla',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            final matchId = state.uri.queryParameters['matchId'];
            return ClanPollaPage(slug: slug, matchId: matchId);
          },
        ),
        GoRoute(
          path: '/clans/:slug/manage',
          name: 'clan-manage',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return ClanManagePage(slug: slug);
          },
        ),
        GoRoute(
          path: '/mapa-crema',
          name: 'mapa-crema',
          builder: (context, state) {
            final matchId = state.uri.queryParameters['matchId'];
            return MapCremaPage(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/historial-crema',
          name: 'historial-crema',
          builder: (context, state) => const HistorialCremaPage(),
        ),
        GoRoute(
          path: '/marketplace',
          name: 'marketplace',
          builder: (context, state) => const MarketplacePage(),
        ),
        GoRoute(
          path: '/marketplace/favorites',
          name: 'marketplace-favorites',
          builder: (context, state) => const FavoritesPage(),
        ),
        GoRoute(
          path: '/marketplace/listings/:slug',
          name: 'marketplace-listing',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return ListingDetailPage(slug: slug);
          },
        ),
        GoRoute(
          path: '/marketplace/stores/:slug',
          name: 'marketplace-store',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return StorePage(slug: slug);
          },
        ),
        GoRoute(
          path: '/marketplace/seller',
          name: 'marketplace-seller',
          builder: (context, state) => const SellerOnboardingPage(),
        ),
        GoRoute(
          path: '/marketplace/seller/dashboard',
          name: 'marketplace-seller-dashboard',
          builder: (context, state) => const SellerDashboardPage(),
        ),
        GoRoute(
          path: '/marketplace/seller/listings/new',
          name: 'marketplace-seller-listing-new',
          builder: (context, state) => const SellerListingFormPage(),
        ),
        GoRoute(
          path: '/marketplace/seller/listings/:slug/edit',
          name: 'marketplace-seller-listing-edit',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return SellerListingFormPage(slug: slug);
          },
        ),
      ],
    ),
  ],
);
