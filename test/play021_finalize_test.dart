import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/session_events.dart';
import 'package:garra_digital_app/core/network/dio_client.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_reply_tile.dart';

DioException _error(int status, Object? body) {
  final options = RequestOptions(path: '/football/chat/messages');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  group('PLAY-02.1 server legal enforcement', () {
    test('428 LEGAL_ACCEPTANCE_REQUIRED is recognised, other errors are not',
        () {
      expect(
        DioClient.isLegalAcceptanceRequired(_error(428, {
          'success': false,
          'errors': {'code': 'LEGAL_ACCEPTANCE_REQUIRED'},
        })),
        isTrue,
      );
      expect(DioClient.isLegalAcceptanceRequired(_error(428, {'errors': {}})),
          isFalse);
      expect(
        DioClient.isLegalAcceptanceRequired(_error(403, {
          'errors': {'code': 'LEGAL_ACCEPTANCE_REQUIRED'},
        })),
        isFalse,
      );
      expect(SessionEventKind.values,
          contains(SessionEventKind.legalAcceptanceRequired));
    });
  });

  group('PLAY-02.1 moderation removal of private messages', () {
    test('moderated message renders the moderation tombstone', () {
      final moderated = ChatMessage.fromJson({
        'id': 'm1',
        'conversationId': 'c1',
        'senderId': 'u1',
        'content': '',
        'mine': false,
        'deleted': true,
        'moderated': true,
      });
      expect(moderated.deleted, isTrue);
      expect(moderated.tombstoneText, 'Mensaje retirado por moderaci\u00f3n');
      expect(moderated.copyWith().moderated, isTrue);
      final ownDelete = ChatMessage.fromJson({
        'id': 'm2',
        'conversationId': 'c1',
        'senderId': 'u1',
        'content': '',
        'mine': true,
        'deleted': true,
      });
      expect(ownDelete.tombstoneText, 'Mensaje eliminado');
    });

    testWidgets('a reply to a withdrawn message says so', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ChatReplyTile(
            reply: ChatReplyPreview.fromJson({
              'id': 'm1',
              'senderId': 'u1',
              'senderName': 'Ana',
              'content': 'Mensaje retirado por moderaci\u00f3n',
              'deleted': true,
            }),
          ),
        ),
      ));
      expect(find.text('Mensaje retirado por moderaci\u00f3n'), findsOneWidget);
    });
  });
}