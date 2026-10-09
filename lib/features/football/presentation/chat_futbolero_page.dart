import 'package:flutter/material.dart';

import '../data/garra_football_models.dart';
import 'football_chat_room_view.dart';

export 'football_chat_room_view.dart' show footballChatServiceProvider, FootballChatEventCard;

/// SONIC_03: Chat Futbolero from Centro Garra (not match Tribuna).
/// SONIC_06: MATCH rooms; GENERAL also reachable here until PRODUCT-03B-5 deep-link cleanup.
class ChatFutboleroPage extends StatelessWidget {
  const ChatFutboleroPage({super.key, this.topic, this.matchId, this.match});

  final String? topic;
  final int? matchId;
  final FootballMatch? match;

  static const pollEvery = FootballChatRoomView.pollEvery;

  @override
  Widget build(BuildContext context) {
    return FootballChatRoomView(
      surface: FootballChatSurface.futbolero,
      topic: topic,
      matchId: matchId,
      initialMatch: match,
    );
  }
}
