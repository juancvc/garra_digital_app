import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:garra_digital_app/core/location/location_service.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/presentation/post_location_picker.dart';
import 'package:garra_digital_app/features/community/presentation/profile_follows_page.dart';
import 'post_links_location_23_test.dart' show FakePoints;

class _Follows extends CommunityService {
  _Follows(this.rows, {this.error = false}) : super(dio: Dio());
  final List<Map<String, dynamic>> rows;
  final bool error;
  bool? requestedFollowers;

  @override
  Future<List<Map<String, dynamic>>> getProfileFollows(String userId,
      {required bool followers}) async {
    requestedFollowers = followers;
    if (error) throw StateError('network');
    return rows;
  }
}

class _Gps extends AppLocationService {
  _Gps(this.result, {this.areaLookup});
  final LocationResult result;
  final Future<String?> Function(double, double)? areaLookup;
  @override
  Future<LocationResult> getCurrentLocation() async => result;
  @override
  Future<String?> resolveSocialArea(double latitude, double longitude) =>
      areaLookup?.call(latitude, longitude) ?? Future.value(null);
}

void main() {
  test('native area resolver returns a trimmed social label', () async {
    const channel = MethodChannel('com.garradigital.app/social_area');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'resolveSocialArea');
      expect(call.arguments, {'latitude': -12.1, 'longitude': -77.0});
      return ' Callao ';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    expect(await AppLocationService().resolveSocialArea(-12.1, -77.0), 'Callao');
  });

  for (final followers in [true, false]) {
    testWidgets('${followers ? 'followers' : 'following'} route renders partial people and returns',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Follows([
        {'userId': 'fan-2', 'username': 'ana', 'displayName': 'Ana',
          'avatarUrl': null, 'isMe': false, 'followedByMe': false},
        {'userId': 'fan-3', 'username': null, 'displayName': null,
          'avatarUrl': null, 'isMe': true, 'followedByMe': false},
      ]);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (context, _) => Scaffold(body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ProfileFollowsPage(userId: 'fan-1',
              followers: followers, service: service),
          )), child: const Text('Abrir lista')))),
        GoRoute(path: '/comunidad/u/:userId', builder: (_, state) =>
          Scaffold(body: Text('PERFIL:${state.pathParameters['userId']}'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(child: MaterialApp.router(
        routerConfig: router)));
      await tester.tap(find.text('Abrir lista'));
      await tester.pumpAndSettle();
      expect(service.requestedFollowers, followers);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      expect(find.text('PERFIL:fan-2'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Abrir lista'), findsOneWidget);
    });
  }

  testWidgets('empty and network failure have visible states', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home:
      ProfileFollowsPage(userId: 'fan', followers: true,
          service: _Follows([])))));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay personas aquí'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(ProviderScope(child: MaterialApp(home:
      ProfileFollowsPage(key: const ValueKey('error'), userId: 'fan', followers: false,
          service: _Follows([], error: true)))));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar esta lista'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow rows remain visible with large system text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2.2)), child: child!),
      home: ProfileFollowsPage(userId: 'fan', followers: false,
        service: _Follows([{'userId': 'fan-2',
          'displayName': 'Nombre de usuario largo', 'username': 'nombre_largo',
          'followedByMe': true, 'isMe': false}])))));
    await tester.pumpAndSettle();
    expect(find.text('Nombre de usuario largo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('followers show primary follow, soft unfollow, and no self action',
      (tester) async {
    final service = _Follows([
      {'userId': 'fan-2', 'displayName': 'Dos', 'followedByMe': true},
      {'userId': 'fan-3', 'displayName': 'Tres', 'followedByMe': false},
      {'userId': 'owner', 'displayName': 'Yo', 'isMe': true},
    ]);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home:
      ProfileFollowsPage(userId: 'owner', followers: true,
          ownerIsMe: true, service: service))));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Dejar de seguir'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Seguir'), findsOneWidget);
    expect(find.descendant(of: find.ancestor(of: find.text('Yo'),
        matching: find.byType(ListTile)), matching: find.byType(ButtonStyleButton)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('following action stays compact at large text scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(2.2)), child: child!),
      home: ProfileFollowsPage(userId: 'owner', followers: false,
          service: _Follows([{'userId': 'fan-2', 'displayName': 'Dos',
            'followedByMe': true}])))));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Dejar de seguir');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, lessThan(280));
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow action is small and aligned with the user at normal width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home:
      ProfileFollowsPage(userId: 'owner', followers: false,
          service: _Follows([{'userId': 'fan-2', 'displayName': 'Dos',
            'followedByMe': true}])))));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Dejar de seguir');
    expect(tester.getSize(button).height, lessThanOrEqualTo(42));
    expect(tester.getSize(button).width, lessThan(160));
    expect((tester.getCenter(button).dy - tester.getCenter(find.text('Dos')).dy)
        .abs(), lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPS map has selected coordinates and confirms only on tap',
      (tester) async {
    final gps = _Gps(const LocationResult(success: true, message: 'ok',
        latitude: -12.1, longitude: -77.0));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          final selected = await pickPostLocation(context,
              locationService: FakePoints(), gpsService: gps);
          if (context.mounted && selected != null) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('RESULT:${selected.name}:${selected.latitude}')));
          }
        }, child: const Text('Agregar ubicación'))),
    ))));
    await tester.tap(find.text('Agregar ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pumpAndSettle();
    expect(find.text('Zona aproximada seleccionada en el mapa'), findsOneWidget);
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.initialCameraPosition.target, const LatLng(-12.1, -77.0));
    expect(map.markers.single.position, const LatLng(-12.1, -77.0));
    final confirm = tester.widget<FilledButton>(find.widgetWithText(
        FilledButton, 'Confirmar ubicación'));
    expect(confirm.onPressed, isNotNull);
    expect(find.textContaining('RESULT:'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('RESULT:Zona aproximada:null'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPS resolves a safe locality and publishes only its label',
      (tester) async {
    String? selected;
    final gps = _Gps(const LocationResult(success: true, message: 'ok',
      latitude: -12.1, longitude: -77.0),
      areaLookup: (latitude, longitude) async {
        expect(latitude, -12.1);
        expect(longitude, -77.0);
        return 'San Miguel';
      });
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          final result = await pickPostLocation(context,
              locationService: FakePoints(), gpsService: gps);
          selected = result?.name;
          expect(result?.latitude, isNull);
          expect(result?.longitude, isNull);
        }, child: const Text('Abrir'))),
    ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pumpAndSettle();
    expect(find.text('Zona seleccionada: San Miguel'), findsOneWidget);
    expect(selected, isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar ubicación'));
    await tester.pumpAndSettle();
    expect(selected, 'San Miguel');
  });

  testWidgets('confirm waits for pending locality instead of publishing fallback',
      (tester) async {
    final area = Completer<String?>();
    String? selected;
    final gps = _Gps(const LocationResult(success: true, message: 'ok',
      latitude: -12.1, longitude: -77.0),
      areaLookup: (_, _) => area.future);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async => selected = (await pickPostLocation(context,
            locationService: FakePoints(), gpsService: gps))?.name,
        child: const Text('Abrir'))),
    ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar ubicación'));
    await tester.pump();
    expect(selected, isNull);
    expect(find.text('Confirmando...'), findsOneWidget);
    area.complete('Callao');
    await tester.pumpAndSettle();
    expect(selected, 'Callao');
  });

  testWidgets('map marker follows visual selection and manual area remains available',
      (tester) async {
    String? selectedName;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          final result = await pickPostLocation(context,
              locationService: FakePoints(), gpsService: _Gps(
                const LocationResult(success: true, message: 'ok',
                    latitude: -12.1, longitude: -77.0)));
          selectedName = result?.name;
        }, child: const Text('Abrir'))),
    ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pumpAndSettle();
    tester.widget<GoogleMap>(find.byType(GoogleMap)).onTap!(
        const LatLng(-12.2, -77.1));
    await tester.pump();
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap))
        .markers.single.position, const LatLng(-12.2, -77.1));
    await tester.enterText(find.widgetWithText(TextField,
        'Ciudad o zona publicable'), 'Miraflores');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar ubicación'));
    await tester.pumpAndSettle();
    expect(selectedName, 'Miraflores');
  });

  testWidgets('GPS denial keeps manual location available', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: PostLocationPicker(locationService: FakePoints(), gpsService: _Gps(
        const LocationResult(success: false, message: 'Permiso denegado'))),
    ))));
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pumpAndSettle();
    expect(find.text('Permiso denegado'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.text('Usar ciudad o zona'), findsOneWidget);
    expect(find.text('Puntos Garra'), findsOneWidget);
  });
}
