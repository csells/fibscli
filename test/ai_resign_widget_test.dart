import 'package:fibscli/dice.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (GammonPlayer, …)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// An engine that resigns immediately (a hopeless position by its own
// judgment); the checker play must never be reached on a resigned turn.
class _ResigningAi extends BgAiPlayer {
  @override
  String get name => 'resigning';

  @override
  Future<BgResignDecision> resignDecision(BgPosition position) async =>
      BgResignDecision.resignSingle;

  @override
  Future<BgTurn> chooseTurn(BgPosition position) async =>
      throw StateError('a resigned turn must not play checkers');
}

// The AI (player two) is on roll, so _maybePlayAi drives its turn.
GammonState _aiOnRoll() => GammonState.from(
  board: GammonState().board,
  dice: [DieState(3), DieState(1)],
  turnPlayer: GammonPlayer.two,
);

void main() {
  testWidgets('an AI resignation ends the game with the human as winner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameView(
            aiSide: GammonPlayer.two,
            ai: _ResigningAi(),
            aiThinkDelay: Duration.zero,
            aiMoveDelay: Duration.zero,
            createGame: _aiOnRoll,
          ),
        ),
      ),
    );

    // build + kick off _maybePlayAi, then let the resignation resolve
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    // the resignation is announced and the human (player one) wins
    expect(find.textContaining('resigns'), findsOneWidget);
    expect(find.text('Player 1 wins!'), findsOneWidget);
  });
}
