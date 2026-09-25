import 'package:flutter/material.dart';
import 'package:garra_digital_app/features/auth/presentation/complete_profile_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_detail_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_invitations_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_manage_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_polla_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_ranking_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_tribuna_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clans_page.dart';
import 'package:garra_digital_app/features/clans/presentation/create_community_page.dart';
import 'package:garra_digital_app/features/admin/presentation/admin_center_page.dart';
import 'package:garra_digital_app/features/admin/presentation/admin_communities_page.dart';
import 'package:garra_digital_app/features/admin/presentation/admin_platform_users_page.dart';
import 'package:garra_digital_app/features/explore/presentation/explore_page.dart';
import 'package:garra_digital_app/features/settings/presentation/settings_pages.dart';
import 'package:garra_digital_app/core/config/app_config_service.dart';
import 'package:garra_digital_app/core/widgets/app_gates.dart';
import 'package:garra_digital_app/features/community/presentation/create_community_post_page.dart';
import 'package:garra_digital_app/features/community/presentation/community_social_page.dart';
import 'package:garra_digital_app/features/community/presentation/global_search_page.dart';
import 'package:garra_digital_app/features/community/presentation/muro_crema_page.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_conversation_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_inbox_page.dart';
import 'package:garra_digital_app/features/community/presentation/saved_posts_page.dart';
import 'package:garra_digital_app/features/solidarity/presentation/solidaria_page.dart';
import 'package:garra_digital_app/features/locations/presentation/business_offers_page.dart';
import 'package:garra_digital_app/features/locations/presentation/mi_negocio_crema_page.dart';
import 'package:garra_digital_app/features/locations/presentation/pick_business_location_page.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_application_service.dart';
import 'package:garra_digital_app/features/history/presentation/history_page.dart';
import 'package:garra_digital_app/features/history/presentation/year_recap_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/favorites_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/listing_detail_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_dashboard_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_listing_form_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_onboarding_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_plan_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/store_page.dart';
import 'package:garra_digital_app/features/missions/presentation/missions_page.dart';
import 'package:garra_digital_app/features/notifications/presentation/notifications_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/passport_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/profile_edit_screen.dart';
import 'package:garra_digital_app/features/referrals/presentation/referrals_page.dart';
import 'package:garra_digital_app/features/rewards/presentation/my_rewards_page.dart';
import 'package:garra_digital_app/features/rewards/presentation/reward_detail_page.dart';
import 'package:garra_digital_app/features/rewards/presentation/rewards_page.dart';
import 'package:garra_digital_app/features/retention/data/retention_models.dart';
import 'package:garra_digital_app/features/retention/presentation/achievements_page.dart';
import 'package:garra_digital_app/features/retention/presentation/admin_retention_pages.dart';
import 'package:garra_digital_app/features/retention/presentation/collection_page.dart';
import 'package:garra_digital_app/features/retention/presentation/events_page.dart';
import 'package:garra_digital_app/features/retention/presentation/onboarding_interests_page.dart';
import 'package:garra_digital_app/features/retention/presentation/season_progress_page.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/splash/presentation/garra_primordial_intro_page.dart';
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
    final isIntro = currentPath == '/intro';
    final isRegister = currentPath == '/register';

    if (isSplash || isIntro) {
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
      path: '/intro',
      name: 'garra-intro',
      builder: (context, state) => const GarraPrimordialIntroPage(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        transitionDuration: const Duration(milliseconds: 280),
        child: const LoginPage(),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
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
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/comunidad',
              name: 'comunidad',
              builder: (context, state) => _featureOrDisabled(
                'community',
                CommunitySocialPage(chatService: ChatService()),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explorar',
              name: 'explorar',
              builder: (context, state) => const ExplorePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/passport',
              name: 'passport',
              builder: (context, state) => const PassportScreen(),
            ),
          ],
        ),
      ],
    ),
    // Deep routes keep stack; bottom nav restored when returning to shell tabs.
    GoRoute(
      path: '/comunidad/compose',
      name: 'comunidad-compose',
      builder: (context, state) => const CreateCommunityPostPage(),
    ),
    GoRoute(
      path: '/comunidad/bloqueados',
      name: 'comunidad-bloqueados',
      builder: (context, state) => const BlockedUsersPage(),
    ),
    GoRoute(
      path: '/comunidad/buscar',
      name: 'comunidad-buscar',
      builder: (context, state) => const GlobalSearchPage(),
    ),
    GoRoute(
      path: '/comunidad/guardados',
      name: 'comunidad-guardados',
      builder: (context, state) => const SavedPostsPage(),
    ),
    GoRoute(
      path: '/comunidad/u/:userId',
      name: 'comunidad-perfil',
      builder: (context, state) =>
          PublicFanProfilePage(userId: state.pathParameters['userId']!),
    ),
    GoRoute(
      path: '/chat',
      name: 'chat-inbox',
      builder: (context, state) => ChatInboxPage(chatService: ChatService()),
    ),
    GoRoute(
      path: '/chat/:conversationId',
      name: 'chat-conversation',
      builder: (context, state) => ChatConversationPage(
        conversationId: state.pathParameters['conversationId']!,
        chatService: ChatService(),
        requestJustSent: state.uri.queryParameters['sent'] == '1',
      ),
    ),
    GoRoute(
      path: '/admin',
      name: 'admin-center',
      builder: (context, state) => const AdminCenterPage(),
    ),
    GoRoute(
      path: '/admin/comunidades',
      name: 'admin-comunidades',
      builder: (context, state) => const AdminCommunitiesReviewPage(),
    ),
    GoRoute(
      path: '/admin/usuarios',
      name: 'admin-usuarios',
      builder: (context, state) => const AdminPlatformUsersPage(),
    ),
    GoRoute(
      path: '/admin/reportes',
      name: 'admin-reportes',
      builder: (context, state) => const AdminReportsPage(),
    ),
    GoRoute(
      path: '/admin/negocios',
      name: 'admin-negocios',
      builder: (context, state) => const AdminBusinessReviewPage(),
    ),
    GoRoute(
      path: '/admin/solidaria',
      name: 'admin-solidaria',
      builder: (context, state) => const AdminSolidarityReviewPage(),
    ),
    GoRoute(
      path: '/admin/marketplace',
      name: 'admin-marketplace',
      builder: (context, state) => const AdminMarketplaceReviewPage(),
    ),
    GoRoute(
      path: '/ruta-templo/ofertas',
      name: 'business-offers',
      builder: (context, state) =>
          _featureOrDisabled('businessOffers', const BusinessOffersPage()),
    ),
    GoRoute(
      path: '/solidaria',
      name: 'solidaria',
      builder: (context, state) =>
          _featureOrDisabled('solidaria', const SolidariaPage()),
    ),
    GoRoute(
      path: '/solidaria/nueva',
      name: 'solidaria-nueva',
      builder: (context, state) => const SolidariaCreatePage(),
    ),
    GoRoute(
      path: '/solidaria/:id',
      name: 'solidaria-detail',
      builder: (context, state) =>
          SolidariaDetailPage(campaignId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/passport/edit',
      name: 'passport-edit',
      builder: (context, state) => const ProfileEditScreen(),
    ),
    GoRoute(
      path: '/passport/temporada',
      name: 'passport-season',
      builder: (context, state) => const SeasonProgressPage(),
    ),
    GoRoute(
      path: '/logros',
      name: 'achievements',
      builder: (context, state) => const AchievementsPage(),
    ),
    GoRoute(
      path: '/coleccion',
      name: 'collection',
      builder: (context, state) => const CollectionPage(),
    ),
    GoRoute(
      path: '/eventos',
      name: 'events',
      builder: (context, state) =>
          _featureOrDisabled('events', const EventsPage()),
    ),
    GoRoute(
      path: '/eventos/nuevo',
      name: 'events-create',
      builder: (context, state) => const CreateEventPage(),
    ),
    GoRoute(
      path: '/eventos/:id',
      name: 'event-detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final extra = state.extra;
        return EventDetailPage(
          eventId: id,
          initial: extra is GarraEventModel ? extra : null,
        );
      },
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding-interests',
      builder: (context, state) => const OnboardingInterestsPage(),
    ),
    GoRoute(
      path: '/admin/temporadas',
      name: 'admin-seasons',
      builder: (context, state) => const AdminSeasonsPage(),
    ),
    GoRoute(
      path: '/admin/logros',
      name: 'admin-achievements',
      builder: (context, state) => const AdminAchievementsPage(),
    ),
    GoRoute(
      path: '/admin/eventos',
      name: 'admin-events',
      builder: (context, state) => const AdminEventsPage(),
    ),
    GoRoute(
      path: '/admin/funciones',
      name: 'admin-features',
      builder: (context, state) => const AdminFeatureFlagsPage(),
    ),
    GoRoute(
      path: '/admin/eliminaciones',
      name: 'admin-deletions',
      builder: (context, state) => const AdminDeletionRequestsPage(),
    ),
    GoRoute(
      path: '/admin/feedback',
      name: 'admin-feedback',
      builder: (context, state) => const AdminBetaFeedbackPage(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsHubPage(),
    ),
    GoRoute(
      path: '/settings/privacy',
      name: 'settings-privacy',
      builder: (context, state) => const PrivacySettingsPage(),
    ),
    GoRoute(
      path: '/settings/legal',
      name: 'settings-legal',
      builder: (context, state) => const LegalSettingsPage(),
    ),
    GoRoute(
      path: '/settings/help',
      name: 'settings-help',
      builder: (context, state) => const HelpDiagnosticsPage(),
    ),
    GoRoute(
      path: '/settings/feedback',
      name: 'settings-feedback',
      builder: (context, state) => const BetaFeedbackPage(),
    ),
    GoRoute(
      path: '/settings/delete-account',
      name: 'settings-delete-account',
      builder: (context, state) => const DeleteAccountPage(),
    ),
    GoRoute(
      path: '/settings/data-export',
      name: 'settings-data-export',
      builder: (context, state) => const DataExportPage(),
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
        return _featureOrDisabled(
          'matchday',
          MatchdayPollsPage(matchId: matchId),
        );
      },
    ),
    GoRoute(
      path: '/matchday/:matchId/polls',
      name: 'matchday-polls',
      builder: (context, state) {
        final matchId = state.pathParameters['matchId'] ?? '';
        return _featureOrDisabled(
          'matchday',
          MatchdayPollsPage(matchId: matchId),
        );
      },
    ),
    GoRoute(
      path: '/ruta-templo',
      name: 'ruta-templo',
      builder: (context, state) => const RutaAlTemploPage(),
    ),
    GoRoute(
      path: '/ruta-templo/mi-negocio',
      name: 'mi-negocio-crema',
      builder: (context, state) => const MiNegocioCremaPage(),
    ),
    GoRoute(
      path: '/ruta-templo/mi-negocio/nuevo',
      name: 'mi-negocio-nuevo',
      builder: (context, state) {
        final existing = state.extra is CremaBusinessApplication
            ? state.extra as CremaBusinessApplication
            : null;
        return RegistrarNegocioCremaPage(existing: existing);
      },
    ),
    GoRoute(
      path: '/ruta-templo/mi-negocio/ubicacion',
      name: 'mi-negocio-ubicacion',
      builder: (context, state) {
        final extra = state.extra is Map
            ? Map<String, dynamic>.from(state.extra as Map)
            : const <String, dynamic>{};
        return PickBusinessLocationPage(
          initialLat: (extra['lat'] as num?)?.toDouble() ?? -12.0553,
          initialLng: (extra['lng'] as num?)?.toDouble() ?? -77.0379,
        );
      },
    ),
    GoRoute(
      path: '/muro-crema',
      name: 'muro-crema',
      builder: (context, state) => const MuroCremaPage(),
    ),
    GoRoute(
      path: '/muro-crema/compose',
      name: 'muro-crema-compose',
      builder: (context, state) {
        final matchId = state.uri.queryParameters['matchId'];
        return CreateCommunityPostPage(matchId: matchId);
      },
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
      path: '/rewards',
      name: 'rewards',
      builder: (context, state) => const RewardsPage(),
    ),
    GoRoute(
      path: '/rewards/me',
      name: 'rewards-me',
      builder: (context, state) => const MyRewardsPage(),
    ),
    GoRoute(
      path: '/rewards/:slug',
      name: 'reward-detail',
      builder: (context, state) {
        final slug = state.pathParameters['slug'] ?? '';
        return RewardDetailPage(slug: slug);
      },
    ),
    GoRoute(
      path: '/referrals',
      name: 'referrals',
      builder: (context, state) => const ReferralsPage(),
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
      path: '/clans/create',
      name: 'clans-create',
      builder: (context, state) => const CreateCommunityPage(),
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
      builder: (context, state) =>
          _featureOrDisabled('marketplace', const MarketplacePage()),
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
        final promotionId = state.uri.queryParameters['promotionId'];
        return ListingDetailPage(slug: slug, promotionId: promotionId);
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
      path: '/marketplace/seller/plan',
      name: 'marketplace-seller-plan',
      builder: (context, state) => const SellerPlanPage(),
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
);

Widget _featureOrDisabled(String flagKey, Widget child) {
  if (appConfigService.current.feature(flagKey)) return child;
  return FeatureDisabledPage(featureName: flagKey);
}
