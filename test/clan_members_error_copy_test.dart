import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_detail_page.dart';

void main() {
  test('clan member server failure does not blame the connection', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/clans/barra/members'),
      response: Response(
        requestOptions: RequestOptions(path: '/clans/barra/members'),
        statusCode: 500,
      ),
      type: DioExceptionType.badResponse,
    );

    expect(clanMembersFailureTitle(error), 'No pudimos cargar los miembros.');
    expect(clanMembersFailureMessage(error), isNot(contains('Revisa tu conexión')));
  });

  test('clan member offline failure asks to check the connection', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/clans/barra/members'),
      type: DioExceptionType.connectionError,
    );

    expect(clanMembersFailureTitle(error), 'No pudimos cargar los miembros.');
    expect(
      clanMembersFailureMessage(error),
      'Revisa tu conexión e inténtalo de nuevo.',
    );
  });
}
