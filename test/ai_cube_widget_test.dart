import 'package:fibscli/game_play_page.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (GammonPlayer, …)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// player two (the AI) is all but home with one checker left; player one is
// stacked far back -- a pure race the AI wins almost surely, so it should
// double.
GammonState _aiDominatingGame() {
  final position = Position(
    points: const [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      -15, // point 12: all 15 of player one's checkers, far back
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      1, // point 24: player two's last checker (1 pip to go)
    ],
    twoOff: 14,
  );
  return GammonState.from(
    board: position.toBoard(),
    dice: const [],
    turnPlayer: GammonPlayer.two, // the AI is on roll
  );
}

void main() {
  testWidgets('the AI offers a double from a dominating position', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameView(
            aiSide: GammonPlayer.two,
            ai: PubevalAiPlayer(),
            aiThinkDelay: Duration.zero,
            aiMoveDelay: Duration.zero,
            createGame: _aiDominatingGame,
          ),
        ),
      ),
    );
    // the AI is on roll; its cube decision should pop the offer dialog
    await tester.pump(); // build + kick off _maybePlayAi
    await tester.pump(); // let the async cube decision resolve

    expect(find.text('Player 2 doubles to 2'), findsOneWidget);

    // accept on the human's behalf; the game should continue without error
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
