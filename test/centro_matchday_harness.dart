// PRODUCT-10A.2E: Centro Garra harness for the Matchday surfaces recovered
// from the ex Home 'Partido' tab (Polla, MVP, Check-in, Misiones/racha).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:go_router/go_router.dart';

class CentroNet extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

class CentroFootballFake extends GarraFootballService {
  CentroFootballFake() : super(dio: Dio());
  final calls = <String>[];

  @override
  Future<List<FootballCompetition>> competitions() async => const [
        FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true,
            region: 'PERU', group: 'peru'),
      ];

  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async {
    calls.add('matches');
    return const FootballPage(items: [], stale: false, unavailable: false, partial: false);
  }

  @override
  Future<FootballFeatured?> featured() async => null;

  @override
  Future<FootballPage<Map<String, dynamic>>> standings(String competition) async =>
      const FootballPage(items: [], stale: false, unavailable: false, partial: false);

  @override
  Future<FootballDetail?> detail(FootballMatch match, {String? section}) async =>
      FootballDetail(match: match, events: const [], lineups: const [],
          statistics: const [], partial: false, stale: false);
}

/// Centro · Para ti · Hoy with [home] as the existing `/home` answer.
Widget pumpCentroMatchday(HomeModel home, {void Function()? onHomeLoad}) {
  final router = GoRouter(initialLocation: '/centro-garra', routes: [
    GoRoute(path: '/centro-garra', builder: (_, _) => const CentroGarraPage()),
    GoRoute(path: '/polla/:matchId', builder: (_, _) =>
        const Scaffold(body: Text('POLLA_ROUTE'))),
    GoRoute(path: '/matchday/:matchId/polls', builder: (_, _) =>
        const Scaffold(body: Text('MATCHDAY_POLLS'))),
    GoRoute(path: '/mapa-crema', builder: (_, s) => Scaffold(body: Text(
        'MAPA_ROUTE:${s.uri.queryParameters['matchId'] ?? ''}'))),
    GoRoute(path: '/missions', builder: (_, s) => Scaffold(body: Text(
        'MISSIONS:${s.uri.queryParameters['matchId'] ?? ''}'))),
  ]);
  return ProviderScope(
    overrides: [
      homeProvider.overrideWith((ref) async {
        onHomeLoad?.call();
        return home;
      }),
      garraFootballServiceProvider.overrideWithValue(CentroFootballFake()),
      connectivityStatusProvider.overrideWith(CentroNet.new),
    ],
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
}

/// Match detail for [match] (countdown lives in its expanded header).
Widget pumpMatchDetail(FootballMatch match) {
  final router = GoRouter(initialLocation: '/d', routes: [
    GoRoute(path: '/d', builder: (_, _) => CentroGarraMatchDetailPage(match: match)),
  ]);
  return ProviderScope(
    overrides: [
      garraFootballServiceProvider.overrideWithValue(CentroFootballFake()),
      connectivityStatusProvider.overrideWith(CentroNet.new),
    ],
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
}
