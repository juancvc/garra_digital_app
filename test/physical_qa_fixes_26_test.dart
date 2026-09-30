import 'dart:async';

import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/location/location_service.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_swipe_to_reply.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/post_location.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_location_picker.dart';
import 'package:garra_digital_app/features/community/presentation/profile_follows_page.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'post_links_location_23_test.dart' show FakePoints;

class _Gps extends AppLocationService {
  int calls = 0;
  @override
  Future<LocationResult> getCurrentLocation() async {
    calls++;
    return const LocationResult(success: false, message: 'Permiso denegado');
  }
}

class _GpsSuccess extends AppLocationService {
  @override
  Future<LocationResult> getCurrentLocation() async => const LocationResult(
    success: true, message: 'ok', latitude: -12.1, longitude: -77.0);
}

class _Follows extends CommunityService {
  _Follows() : super(dio: Dio());
  int follows = 0;
  int unfollows = 0;
  @override
  Future<List<Map<String, dynamic>>> getProfileFollows(String userId,
      {required bool followers}) async => [
    {'userId': 'other', 'username': 'ana', 'displayName': 'Ana',
     'followedByMe': true, 'isMe': false},
  ];
  @override
  Future<void> followUser(String userId) async { follows++; }
  @override
  Future<void> unfollowUser(String userId) async { unfollows++; }
}

class _OnlineSource implements ConnectivitySource {
  @override
  Future<List<ConnectivityResult>> check() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get changes =>
      const Stream<List<ConnectivityResult>>.empty();
}

void main() {
  testWidgets('swipe follows finger, threshold replies once, then resets', (tester) async {
    var replies = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: ChatSwipeToReply(onReply: () => replies++,
        child: const SizedBox(width: 180, height: 60, child: Text('Mensaje'))),
    ))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Mensaje')));
    await gesture.moveBy(const Offset(38, 0));
    await tester.pump();
    final moved = tester.getTopLeft(find.text('Mensaje')).dx;
    expect(moved, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(replies, 0);
    final start = tester.getTopLeft(find.text('Mensaje')).dx;
    final full = await tester.startGesture(tester.getCenter(find.text('Mensaje')));
    await full.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.text('Mensaje')).dx, greaterThan(start));
    await full.up();
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(tester.getTopLeft(find.text('Mensaje')).dx, closeTo(start, 1));
  });

  testWidgets('vertical chat scroll does not start a reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(
      children: [for (var i = 0; i < 30; i++)
        ChatSwipeToReply(onReply: () => replies++,
          child: SizedBox(height: 70, child: Text('Mensaje $i')))],
    ))));
    await tester.drag(find.text('Mensaje 2'), const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(replies, 0);
    expect(find.text('Mensaje 8'), findsWidgets);
  });

  testWidgets('GPS is requested only by explicit action; denial keeps manual picker', (tester) async {
    final gps = _Gps();
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: PostLocationPicker(locationService: FakePoints(), gpsService: gps),
    ))));
    await tester.pumpAndSettle();
    expect(gps.calls, 0);
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pump();
    expect(gps.calls, 1);
    expect(find.text('Usar ciudad o zona'), findsOneWidget);
    expect(find.text('Puntos Garra'), findsOneWidget);
    expect(confirmedPostArea(' Cusco ').toJson(),
        {'name': 'Cusco', 'kind': 'CITY_OR_AREA'});
  });

  testWidgets('GPS never attaches location before map confirmation', (tester) async {
    final confirmation = Completer<PostLocation?>();
    PostLocation? selected;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async => selected = await pickPostLocation(context,
          locationService: FakePoints(), gpsService: _GpsSuccess(),
          confirmCurrentLocation: (_, _) => confirmation.future),
        child: const Text('Agregar ubicación'),
      )),
    ))));
    await tester.tap(find.text('Agregar ubicación'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pump();
    expect(selected, isNull);
    confirmation.complete(confirmedPostArea(' Lima '));
    await tester.pumpAndSettle();
    expect(selected?.name, 'Lima');
    expect(selected?.latitude, isNull);
    expect(selected?.longitude, isNull);
  });

  testWidgets('followers post shows privacy and has no share action', (tester) async {
    final post = WallPostModel.fromJson({
      'id': 'p', 'username': 'ana', 'fullName': 'Ana', 'content': 'Solo fans',
      'status': 'ACTIVE', 'contextType': 'GLOBAL', 'visibility': 'FOLLOWERS',
      'createdAt': '2026-09-29T12:00:00Z',
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        GarraSocialPostCard(post: post, onOpen: () {}, onShare: () {}))));
    expect(find.text('Solo seguidores'), findsOneWidget);
    expect(find.text('Compartir'), findsNothing);
    expect(WallPostModel.fromJson({'id': 'legacy'}).visibility, 'PUBLIC');
  });

  testWidgets('Following can unfollow and follow with local row update', (tester) async {
    final service = _Follows();
    await tester.pumpWidget(ProviderScope(
        overrides: [connectivitySourceProvider.overrideWithValue(_OnlineSource())],
        child: MaterialApp(home:
        ProfileFollowsPage(userId: 'owner', followers: false, service: service))));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(ListTile), matching: find.text('Siguiendo')));
    await tester.pumpAndSettle();
    expect(service.unfollows, 1);
    expect(find.text('Seguir'), findsOneWidget);
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
    expect(service.follows, 1);
  });

  testWidgets('own Following removes unfollowed row and updates count', (tester) async {
    final service = _Follows();
    var delta = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [connectivitySourceProvider.overrideWithValue(_OnlineSource())],
      child: MaterialApp(home: ProfileFollowsPage(
        userId: 'owner', followers: false, service: service,
        ownerIsMe: true, onOwnFollowingCountChanged: (value) => delta += value,
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(ListTile), matching: find.text('Siguiendo')));
    await tester.pumpAndSettle();
    expect(service.unfollows, 1);
    expect(delta, -1);
    expect(find.text('Todavía no hay personas aquí'), findsOneWidget);
  });
}

