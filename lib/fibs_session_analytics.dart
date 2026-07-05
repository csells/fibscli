import 'package:flutter/foundation.dart';

import 'fibs_session.dart';

@immutable
class FibsSessionAnalyticsEvent {
  const FibsSessionAnalyticsEvent({
    required this.name,
    required this.screen,
    this.mode,
    this.result = 'accepted',
  });

  final String name;
  final String screen;
  final String? mode;
  final String result;
}

List<FibsSessionAnalyticsEvent> fibsSessionAnalyticsEvents({
  required FibsSession before,
  required FibsSession after,
}) {
  final events = <FibsSessionAnalyticsEvent>[];
  final wasInGame = before.board != null;
  final inGame = after.board != null;

  if (!wasInGame && inGame) {
    final watching = after.myColor == null;
    events.add(
      FibsSessionAnalyticsEvent(
        name: 'app_fibs_game_start',
        screen: watching ? 'fibs_watch' : 'fibs_play',
        mode: watching ? 'watching' : 'playing',
      ),
    );
  }

  if (!before.isGameOver && after.isGameOver) {
    events.add(
      FibsSessionAnalyticsEvent(
        name: 'app_fibs_game_end',
        screen: 'fibs_play',
        result: _resultFor(after),
      ),
    );
  }

  return events;
}

String _resultFor(FibsSession session) {
  final announced = session.iWon;
  if (announced != null) return announced ? 'win' : 'loss';
  final winner = session.board?.winner;
  if (winner == null || session.myColor == null) return 'unknown';
  return winner == session.myColor ? 'win' : 'loss';
}
