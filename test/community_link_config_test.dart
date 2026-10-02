import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/config/community_link_config.dart';
import 'package:garra_digital_app/core/router/app_router.dart';

void main() {
  testWidgets('canonical community path resolves through existing router', (tester) async {
    final router = createAppRouter(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'community-link'),
      initialLocation: '/comunidades/garra-surco',
      redirect: (_, _) => null,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(router.routeInformationProvider.value.uri.path, '/clans/garra-surco');
  });

  test('public community share uses a canonical HTTPS link and no credentials', () {
    final text = CommunityLinkConfig.shareText(
      'Garra Surco',
      'garra-surco',
      baseUrl: 'https://garra.example',
    );
    expect(text, 'Únete a Garra Surco en Garra Digital\n'
        'https://garra.example/comunidades/garra-surco');
    expect(text, isNot(contains('token=')));
    expect(text, isNot(contains('@usuario')));
  });

  test('missing or unsafe host cannot create a share link', () {
    expect(CommunityLinkConfig.communityUri('garra-surco', baseUrl: ''), isNull);
    expect(CommunityLinkConfig.communityUri('garra-surco', baseUrl: 'http://garra.example'), isNull);
    expect(CommunityLinkConfig.communityUri('garra-surco', baseUrl: 'https://user:pass@garra.example'), isNull);
    expect(CommunityLinkConfig.communityUri('../admin', baseUrl: 'https://garra.example'), isNull);
  });

  test('only valid community targets survive login redirect', () {
    expect(CommunityLinkConfig.safeDestination('/comunidades/garra-surco'), '/clans/garra-surco');
    expect(CommunityLinkConfig.safeDestination('/clans/garra-surco'), '/clans/garra-surco');
    expect(CommunityLinkConfig.safeDestination('https://evil.example/clans/garra-surco'), isNull);
    expect(CommunityLinkConfig.safeDestination('//evil.example'), isNull);
    expect(CommunityLinkConfig.safeDestination('/clans/garra-surco?next=/admin'), isNull);
  });
}
