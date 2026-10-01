import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/presentation/global_search_page.dart';

class _SearchService extends CommunityService {
  _SearchService() : super(dio: Dio());
  final queries = <String>[];

  @override
  Future<Map<String, dynamic>> globalSearch(String q, {String? type}) async {
    queries.add(q);
    return {
      'fans': [
        {'id': 'fan-1', 'username': 'juancrema', 'displayName': 'Juan Crema',
          'avatarUrl': 'https://example.invalid/avatar.jpg'}
      ],
      'communities': [], 'businesses': [], 'marketplace': [], 'solidarity': [],
    };
  }
}

void main() {
  testWidgets('global autocomplete removes @ and renders profile identity', (tester) async {
    final service = _SearchService();
    await tester.pumpWidget(MaterialApp(home: GlobalSearchPage(service: service)));
    await tester.enterText(find.byType(TextField).first, '@ju');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(service.queries, ['ju']);
    expect(find.text('Juan Crema'), findsOneWidget);
    expect(find.text('@juancrema'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '@j');
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.queries, ['ju']);
    expect(find.text('Busca una persona'), findsOneWidget);
  });
}
